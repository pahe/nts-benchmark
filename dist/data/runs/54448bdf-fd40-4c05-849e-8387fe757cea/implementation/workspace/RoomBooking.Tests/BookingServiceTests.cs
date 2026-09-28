using System; using System.Threading; using System.Threading.Tasks; using Microsoft.EntityFrameworkCore; using RoomBooking.Web.Contracts; using RoomBooking.Web.Data; using RoomBooking.Web.Models; using RoomBooking.Web.Services; using Xunit;
namespace RoomBooking.Tests;
public class BookingServiceTests
{
 private static BookingService Service(){var o=new DbContextOptionsBuilder<RoomBookingDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;var f=new TestFactory(o);using var db=f.CreateDbContext();db.Rooms.AddRange(new Room{Id=1,Name="Alfa",Capacity=4,IsActive=true},new Room{Id=2,Name="Gamma",Capacity=12,IsActive=false});db.SaveChanges();return new BookingService(f);}
 private static BookingRequest Request(int room=1,int start=10,int end=11)=>new(){Title="Möte",BookedBy="Anna",RoomId=room,StartTime=DateTimeOffset.UtcNow.Date.AddDays(1).AddHours(start),EndTime=DateTimeOffset.UtcNow.Date.AddDays(1).AddHours(end)};
 [Fact] public async Task Overlap_is_rejected(){var s=Service();Assert.NotNull((await s.CreateAsync(Request())).Value);var r=Request();r.StartTime=r.StartTime.AddMinutes(30);r.EndTime=r.EndTime.AddMinutes(30);Assert.Equal(409,(await s.CreateAsync(r)).Code);}
 [Fact] public async Task Adjacent_is_allowed(){var s=Service();Assert.NotNull((await s.CreateAsync(Request())).Value);var r=Request(start:11,end:12);Assert.NotNull((await s.CreateAsync(r)).Value);}
 [Fact] public async Task Cancelled_does_not_block(){var s=Service();var b=(await s.CreateAsync(Request())).Value!;Assert.True(await s.CancelAsync(b.Id));Assert.NotNull((await s.CreateAsync(Request())).Value);}
 [Fact] public async Task Inactive_room_is_rejected(){Assert.Equal(409,(await Service().CreateAsync(Request(2))).Code);}
 [Fact] public async Task Invalid_range_is_rejected(){var r=Request();r.EndTime=r.StartTime;Assert.Equal(400,(await Service().CreateAsync(r)).Code);}
 private sealed class TestFactory(DbContextOptions<RoomBookingDbContext> o):IDbContextFactory<RoomBookingDbContext>{public RoomBookingDbContext CreateDbContext()=>new(o);public Task<RoomBookingDbContext>CreateDbContextAsync(CancellationToken c=default)=>Task.FromResult(new RoomBookingDbContext(o));}
}
