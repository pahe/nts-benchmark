using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using RoomBooking.Web.Contracts;
using RoomBooking.Web.Data;
using RoomBooking.Web.Models;

namespace RoomBooking.Web.Services;

public enum BookingError { Validation, NotFound, Conflict }
public sealed class BookingException(BookingError kind, string message, string? field = null) : Exception(message)
{
    public BookingError Kind { get; } = kind;
    public string? Field { get; } = field;
}

public interface IBookingService
{
    Task<IReadOnlyList<RoomDto>> GetRoomsAsync(bool activeOnly = false);
    Task<IReadOnlyList<BookingDto>> GetBookingsAsync(BookingFilter filter);
    Task<BookingDto?> GetBookingAsync(int id);
    Task<BookingDto> CreateAsync(BookingInput input);
    Task<BookingDto> UpdateAsync(int id, BookingInput input);
    Task<BookingDto> CancelAsync(int id);
}

public sealed class BookingService(IDbContextFactory<RoomBookingDbContext> factory) : IBookingService
{
    // Serializes mutations in this process. SQLite's write transaction also protects the database across processes.
    private static readonly SemaphoreSlim WriteLock = new(1, 1);

    public async Task<IReadOnlyList<RoomDto>> GetRoomsAsync(bool activeOnly = false)
    {
        await using var db = await factory.CreateDbContextAsync();
        return await db.Rooms.AsNoTracking().Where(r => !activeOnly || r.IsActive)
            .OrderBy(r => r.Name).Select(r => new RoomDto(r.Id, r.Name, r.Capacity, r.IsActive)).ToListAsync();
    }

    public async Task<IReadOnlyList<BookingDto>> GetBookingsAsync(BookingFilter filter)
    {
        await using var db = await factory.CreateDbContextAsync();
        var query = db.Bookings.AsNoTracking().Include(b => b.Room).AsQueryable();
        if (filter.RoomId is { } roomId) query = query.Where(b => b.RoomId == roomId);
        if (filter.Date is { } date)
        {
            var begin = date.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
            var end = begin.AddDays(1);
            query = query.Where(b => b.StartUtc < end && b.EndUtc > begin);
        }
        if (!string.IsNullOrWhiteSpace(filter.Status))
        {
            if (!Enum.TryParse<BookingStatus>(filter.Status, true, out var status))
                throw new BookingException(BookingError.Validation, "Ogiltig status.", "status");
            query = query.Where(b => b.Status == status);
        }
        var bookings = await query.OrderBy(b => b.StartUtc).ToListAsync();
        return bookings.Select(ToDto).ToList();
    }

    public async Task<BookingDto?> GetBookingAsync(int id)
    {
        await using var db = await factory.CreateDbContextAsync();
        var booking = await db.Bookings.AsNoTracking().Include(b => b.Room).FirstOrDefaultAsync(b => b.Id == id);
        return booking is null ? null : ToDto(booking);
    }

    public Task<BookingDto> CreateAsync(BookingInput input) => WriteAsync(async db =>
    {
        await ValidateAsync(db, input);
        var booking = new Booking
        {
            Title = input.Title.Trim(), BookedBy = input.BookedBy.Trim(), RoomId = input.RoomId,
            StartUtc = input.StartTime.UtcDateTime, EndUtc = input.EndTime.UtcDateTime,
            CreatedUtc = DateTime.UtcNow
        };
        db.Bookings.Add(booking);
        await db.SaveChangesAsync();
        await db.Entry(booking).Reference(b => b.Room).LoadAsync();
        return ToDto(booking);
    });

    public Task<BookingDto> UpdateAsync(int id, BookingInput input) => WriteAsync(async db =>
    {
        var booking = await db.Bookings.Include(b => b.Room).FirstOrDefaultAsync(b => b.Id == id)
            ?? throw new BookingException(BookingError.NotFound, "Bokningen finns inte.");
        if (booking.Status == BookingStatus.Cancelled)
            throw new BookingException(BookingError.Conflict, "En avbokad bokning kan inte redigeras.");
        await ValidateAsync(db, input, id);
        booking.Title = input.Title.Trim(); booking.BookedBy = input.BookedBy.Trim();
        booking.RoomId = input.RoomId; booking.StartUtc = input.StartTime.UtcDateTime;
        booking.EndUtc = input.EndTime.UtcDateTime;
        await db.SaveChangesAsync();
        await db.Entry(booking).Reference(b => b.Room).LoadAsync();
        return ToDto(booking);
    });

    public Task<BookingDto> CancelAsync(int id) => WriteAsync(async db =>
    {
        var booking = await db.Bookings.Include(b => b.Room).FirstOrDefaultAsync(b => b.Id == id)
            ?? throw new BookingException(BookingError.NotFound, "Bokningen finns inte.");
        if (booking.Status != BookingStatus.Cancelled)
        {
            booking.Status = BookingStatus.Cancelled;
            await db.SaveChangesAsync();
        }
        return ToDto(booking);
    });

    private static async Task ValidateAsync(RoomBookingDbContext db, BookingInput input, int? excludeId = null)
    {
        if (input is null) throw new BookingException(BookingError.Validation, "Bokningsuppgifter saknas.");
        var results = new List<ValidationResult>();
        Validator.TryValidateObject(input, new ValidationContext(input), results, true);
        if (results.Count > 0) throw new BookingException(BookingError.Validation, results[0].ErrorMessage ?? "Ogiltig inmatning.", results[0].MemberNames.FirstOrDefault());
        if (string.IsNullOrWhiteSpace(input.Title)) throw new BookingException(BookingError.Validation, "Rubrik krävs.", nameof(input.Title));
        if (string.IsNullOrWhiteSpace(input.BookedBy)) throw new BookingException(BookingError.Validation, "Bokarens namn krävs.", nameof(input.BookedBy));
        if (input.EndTime <= input.StartTime) throw new BookingException(BookingError.Validation, "Sluttiden måste vara senare än starttiden.", nameof(input.EndTime));
        if (input.StartTime < DateTimeOffset.UtcNow) throw new BookingException(BookingError.Validation, "Starttiden får inte vara bakåt i tiden.", nameof(input.StartTime));
        var room = await db.Rooms.FindAsync(input.RoomId);
        if (room is null) throw new BookingException(BookingError.NotFound, "Mötesrummet finns inte.", nameof(input.RoomId));
        if (!room.IsActive) throw new BookingException(BookingError.Conflict, "Mötesrummet är inaktivt.", nameof(input.RoomId));
        var start = input.StartTime.UtcDateTime;
        var end = input.EndTime.UtcDateTime;
        if (await db.Bookings.AnyAsync(b => b.RoomId == input.RoomId && b.Status == BookingStatus.Active &&
                b.Id != excludeId && start < b.EndUtc && end > b.StartUtc))
            throw new BookingException(BookingError.Conflict, "Mötesrummet är redan bokat under denna tid.", nameof(input.StartTime));
    }

    private async Task<T> WriteAsync<T>(Func<RoomBookingDbContext, Task<T>> action)
    {
        await WriteLock.WaitAsync();
        try
        {
            await using var db = await factory.CreateDbContextAsync();
            await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
            var result = await action(db);
            await tx.CommitAsync();
            return result;
        }
        catch (DbUpdateException)
        {
            throw new BookingException(BookingError.Conflict, "Bokningen kunde inte sparas. Försök igen.");
        }
        finally { WriteLock.Release(); }
    }

    private static BookingDto ToDto(Booking b) => new(b.Id, b.Title, b.BookedBy, b.RoomId, b.Room.Name,
        new DateTimeOffset(DateTime.SpecifyKind(b.StartUtc, DateTimeKind.Utc)),
        new DateTimeOffset(DateTime.SpecifyKind(b.EndUtc, DateTimeKind.Utc)),
        b.Status == BookingStatus.Active ? "active" : "cancelled",
        new DateTimeOffset(DateTime.SpecifyKind(b.CreatedUtc, DateTimeKind.Utc)));
}
