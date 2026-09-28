using System.ComponentModel.DataAnnotations;

namespace RoomBooking.Web.Models;

public sealed class Room
{
    public int Id { get; set; }
    [Required, MaxLength(100)] public string Name { get; set; } = "";
    public int Capacity { get; set; }
    public bool IsActive { get; set; } = true;
}
