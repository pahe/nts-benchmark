using System.ComponentModel.DataAnnotations;

namespace RoomBooking.Web.Contracts;

public sealed class BookingInput
{
    [Required, MaxLength(200)] public string Title { get; set; } = "";
    [Required, MaxLength(100)] public string BookedBy { get; set; } = "";
    [Range(1, int.MaxValue)] public int RoomId { get; set; }
    public DateTimeOffset StartTime { get; set; }
    public DateTimeOffset EndTime { get; set; }
}

public sealed record RoomDto(int Id, string Name, int Capacity, bool IsActive);
public sealed record BookingDto(int Id, string Title, string BookedBy, int RoomId, string RoomName,
    DateTimeOffset StartTime, DateTimeOffset EndTime, string Status, DateTimeOffset CreatedAt);

public sealed record BookingFilter(int? RoomId = null, DateOnly? Date = null, string? Status = null);
