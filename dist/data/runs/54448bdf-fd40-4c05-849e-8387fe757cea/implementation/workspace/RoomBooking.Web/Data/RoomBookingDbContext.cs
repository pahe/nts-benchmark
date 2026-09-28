using Microsoft.EntityFrameworkCore; using RoomBooking.Web.Models;
namespace RoomBooking.Web.Data;
public sealed class RoomBookingDbContext(DbContextOptions<RoomBookingDbContext> options):DbContext(options) { public DbSet<Room> Rooms=>Set<Room>(); public DbSet<Booking> Bookings=>Set<Booking>(); protected override void OnModelCreating(ModelBuilder b){b.Entity<Room>().HasIndex(x=>x.Name).IsUnique();b.Entity<Booking>().Property(x=>x.Status).HasConversion<string>();b.Entity<Booking>().HasOne(x=>x.Room).WithMany(x=>x.Bookings).HasForeignKey(x=>x.RoomId).OnDelete(DeleteBehavior.Restrict);} }
