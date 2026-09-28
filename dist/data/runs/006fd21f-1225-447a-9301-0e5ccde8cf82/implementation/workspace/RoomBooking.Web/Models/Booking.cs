using System.ComponentModel.DataAnnotations;

namespace RoomBooking.Web.Models;

public enum BookingStatus { Active, Cancelled }

public sealed class Booking
{
    public int Id { get; set; }
    [Required, MaxLength(200)] public string Title { get; set; } = "";
    [Required, MaxLength(100)] public string BookedBy { get; set; } = "";
    public int RoomId { get; set; }
    public Room Room { get; set; } = null!;
    public DateTime StartUtc { get; set; }
    public DateTime EndUtc { get; set; }
    public BookingStatus Status { get; set; } = BookingStatus.Active;
    public DateTime CreatedUtc { get; set; }
}
