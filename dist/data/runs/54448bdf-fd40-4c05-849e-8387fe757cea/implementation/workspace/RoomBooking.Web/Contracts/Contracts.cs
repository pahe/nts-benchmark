using System.ComponentModel.DataAnnotations; using RoomBooking.Web.Models;
namespace RoomBooking.Web.Contracts;
public sealed class BookingRequest { [Required] public string Title { get; set; } = ""; [Required] public string BookedBy { get; set; } = ""; [Range(1,int.MaxValue)] public int RoomId { get; set; } public DateTimeOffset StartTime { get; set; } public DateTimeOffset EndTime { get; set; } }
public sealed record RoomResponse(int Id,string Name,int Capacity,bool IsActive);
public sealed record BookingResponse(int Id,string Title,string BookedBy,int RoomId,string RoomName,DateTimeOffset StartTime,DateTimeOffset EndTime,BookingStatus Status,DateTimeOffset CreatedAt);
