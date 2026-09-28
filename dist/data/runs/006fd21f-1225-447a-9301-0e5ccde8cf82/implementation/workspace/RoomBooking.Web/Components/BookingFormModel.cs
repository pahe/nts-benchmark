using System.ComponentModel.DataAnnotations;
using RoomBooking.Web.Contracts;

namespace RoomBooking.Web.Components;

public sealed class BookingFormModel : IValidatableObject
{
    [Required(ErrorMessage = "Rubrik krävs.")] public string Title { get; set; } = "";
    [Required(ErrorMessage = "Bokarens namn krävs.")] public string BookedBy { get; set; } = "";
    [Range(1, int.MaxValue, ErrorMessage = "Välj ett mötesrum.")] public int RoomId { get; set; }
    public DateTime Date { get; set; } = DateTime.UtcNow.Date.AddDays(1);
    [Required(ErrorMessage = "Starttid krävs.")] public string Start { get; set; } = "09:00";
    [Required(ErrorMessage = "Sluttid krävs.")] public string End { get; set; } = "10:00";

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (Date == default) yield return new ValidationResult("Datum krävs.", [nameof(Date)]);
        if (!TimeOnly.TryParse(Start, out var start)) yield return new ValidationResult("Ogiltig starttid.", [nameof(Start)]);
        if (!TimeOnly.TryParse(End, out var end)) yield return new ValidationResult("Ogiltig sluttid.", [nameof(End)]);
        if (TimeOnly.TryParse(Start, out start) && TimeOnly.TryParse(End, out end) && end <= start)
            yield return new ValidationResult("Sluttiden måste vara senare än starttiden.", [nameof(End)]);
    }

    public static BookingFormModel From(BookingDto booking) => new()
    {
        Title = booking.Title, BookedBy = booking.BookedBy, RoomId = booking.RoomId,
        Date = booking.StartTime.UtcDateTime.Date,
        Start = booking.StartTime.ToString("HH:mm", System.Globalization.CultureInfo.InvariantCulture),
        End = booking.EndTime.ToString("HH:mm", System.Globalization.CultureInfo.InvariantCulture)
    };
}
