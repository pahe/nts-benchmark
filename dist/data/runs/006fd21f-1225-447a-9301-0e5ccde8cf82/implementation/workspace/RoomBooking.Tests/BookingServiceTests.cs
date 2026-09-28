using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using RoomBooking.Web.Contracts;
using RoomBooking.Web.Data;
using RoomBooking.Web.Models;
using RoomBooking.Web.Services;

namespace RoomBooking.Tests;

public sealed class BookingServiceTests : IAsyncLifetime
{
    private readonly string path = Path.Combine(Path.GetTempPath(), $"roombooking-{Guid.NewGuid():N}.db");
    private readonly IDbContextFactory<RoomBookingDbContext> factory;
    private readonly BookingService service;

    public BookingServiceTests()
    {
        var options = new DbContextOptionsBuilder<RoomBookingDbContext>().UseSqlite($"Data Source={path}").Options;
        factory = new PooledDbContextFactory<RoomBookingDbContext>(options);
        service = new BookingService(factory);
    }

    public async Task InitializeAsync()
    {
        await using var db = await factory.CreateDbContextAsync();
        await db.Database.EnsureCreatedAsync();
        db.Rooms.AddRange(new Room { Name = "Alfa", Capacity = 4 }, new Room { Name = "Inaktiv", Capacity = 8, IsActive = false });
        await db.SaveChangesAsync();
    }
    public Task DisposeAsync()
    {
        (factory as IDisposable)?.Dispose();
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        if (File.Exists(path)) File.Delete(path);
        return Task.CompletedTask;
    }

    private static BookingInput Input(DateTimeOffset start, DateTimeOffset end, int room = 1) => new()
    { Title = "Möte", BookedBy = "Anna", RoomId = room, StartTime = start, EndTime = end };

    [Fact]
    public async Task Overlap_is_rejected_but_adjacent_and_cancelled_slots_are_available()
    {
        var start = DateTimeOffset.UtcNow.AddDays(2);
        var first = await service.CreateAsync(Input(start, start.AddHours(1)));
        var collision = await Assert.ThrowsAsync<BookingException>(() => service.CreateAsync(Input(start.AddMinutes(30), start.AddHours(2))));
        Assert.Equal(BookingError.Conflict, collision.Kind);
        var adjacent = await service.CreateAsync(Input(start.AddHours(1), start.AddHours(2)));
        Assert.Equal("active", adjacent.Status);
        await service.CancelAsync(first.Id);
        var replacement = await service.CreateAsync(Input(start, start.AddHours(1)));
        Assert.Equal("active", replacement.Status);
    }

    [Fact]
    public async Task Editing_itself_succeeds_but_inactive_room_and_invalid_interval_fail()
    {
        var start = DateTimeOffset.UtcNow.AddDays(3);
        var booking = await service.CreateAsync(Input(start, start.AddHours(1)));
        Assert.Equal(booking.Id, (await service.UpdateAsync(booking.Id, Input(start, start.AddHours(1)))).Id);
        Assert.Equal(BookingError.Conflict, (await Assert.ThrowsAsync<BookingException>(() => service.CreateAsync(Input(start, start.AddHours(1), 2)))).Kind);
        Assert.Equal(BookingError.Validation, (await Assert.ThrowsAsync<BookingException>(() => service.CreateAsync(Input(start, start)))).Kind);
    }

    [Fact]
    public async Task Concurrent_overlapping_creates_allow_only_one()
    {
        var start = DateTimeOffset.UtcNow.AddDays(4);
        var outcomes = await Task.WhenAll(Enumerable.Range(0, 2).Select(async _ =>
        {
            try { await service.CreateAsync(Input(start, start.AddHours(1))); return true; }
            catch (BookingException ex) when (ex.Kind == BookingError.Conflict) { return false; }
        }));
        Assert.Single(outcomes, x => x);
    }
}
