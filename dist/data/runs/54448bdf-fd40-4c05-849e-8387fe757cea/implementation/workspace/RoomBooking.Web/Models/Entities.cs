namespace RoomBooking.Web.Models;
public enum BookingStatus { Active, Cancelled }
public sealed class Room { public int Id { get; set; } public string Name { get; set; } = ""; public int Capacity { get; set; } public bool IsActive { get; set; } public List<Booking> Bookings { get; set; } = []; }
public sealed class Booking { public int Id { get; set; } public string Title { get; set; } = ""; public string BookedBy { get; set; } = ""; public int RoomId { get; set; } public Room? Room { get; set; } public DateTimeOffset StartTime { get; set; } public DateTimeOffset EndTime { get; set; } public BookingStatus Status { get; set; } = BookingStatus.Active; public DateTimeOffset CreatedAt { get; set; } }
