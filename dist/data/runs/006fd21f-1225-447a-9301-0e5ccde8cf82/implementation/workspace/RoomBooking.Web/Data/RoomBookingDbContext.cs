using Microsoft.EntityFrameworkCore;
using RoomBooking.Web.Models;

namespace RoomBooking.Web.Data;

public sealed class RoomBookingDbContext(DbContextOptions<RoomBookingDbContext> options) : DbContext(options)
{
    public DbSet<Room> Rooms => Set<Room>();
    public DbSet<Booking> Bookings => Set<Booking>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Room>().HasIndex(r => r.Name).IsUnique();
        modelBuilder.Entity<Booking>().HasIndex(b => new { b.RoomId, b.StartUtc, b.EndUtc });
        modelBuilder.Entity<Booking>().Property(b => b.Status).HasConversion<string>();
    }
}
