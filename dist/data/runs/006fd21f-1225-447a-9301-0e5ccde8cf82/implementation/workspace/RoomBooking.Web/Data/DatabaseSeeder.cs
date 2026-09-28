using Microsoft.EntityFrameworkCore;
using RoomBooking.Web.Models;

namespace RoomBooking.Web.Data;

public static class DatabaseSeeder
{
    public static async Task SeedAsync(RoomBookingDbContext db)
    {
        await db.Database.EnsureCreatedAsync();
        if (await db.Rooms.AnyAsync()) return;
        db.Rooms.AddRange(
            new Room { Name = "Alfa", Capacity = 4 },
            new Room { Name = "Beta", Capacity = 8 },
            new Room { Name = "Gamma", Capacity = 12, IsActive = false });
        await db.SaveChangesAsync();
        var start = DateTime.UtcNow.Date.AddDays(1).AddHours(10);
        db.Bookings.Add(new Booking
        {
            Title = "Exempelmöte", BookedBy = "Anna Andersson", RoomId = (await db.Rooms.FirstAsync(r => r.Name == "Alfa")).Id,
            StartUtc = start, EndUtc = start.AddHours(1), CreatedUtc = DateTime.UtcNow
        });
        await db.SaveChangesAsync();
    }
}
