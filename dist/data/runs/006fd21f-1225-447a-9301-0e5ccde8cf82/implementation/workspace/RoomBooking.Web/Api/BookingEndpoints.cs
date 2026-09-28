using RoomBooking.Web.Contracts;
using RoomBooking.Web.Services;

namespace RoomBooking.Web.Api;

public static class BookingEndpoints
{
    public static IEndpointRouteBuilder MapBookingApi(this IEndpointRouteBuilder app)
    {
        var rooms = app.MapGroup("/api/rooms").WithTags("Rooms");
        rooms.MapGet("/", async (bool? activeOnly, IBookingService service) =>
            Results.Ok(await service.GetRoomsAsync(activeOnly ?? false)));

        var bookings = app.MapGroup("/api/bookings").WithTags("Bookings");
        bookings.MapGet("/", async (int? roomId, DateOnly? date, string? status, IBookingService service) =>
            await Safe(async () => Results.Ok(await service.GetBookingsAsync(new(roomId, date, status)))));
        bookings.MapGet("/{id:int}", async (int id, IBookingService service) =>
            await Safe(async () => (IResult)(await service.GetBookingAsync(id) is { } booking
                ? Results.Ok(booking) : Missing("Bokningen finns inte."))));
        bookings.MapPost("/", async (BookingInput? input, IBookingService service) =>
            await Safe(async () =>
            {
                if (input is null) return Invalid("Bokningsuppgifter saknas.");
                var created = await service.CreateAsync(input);
                return Results.Created($"/api/bookings/{created.Id}", created);
            }));
        bookings.MapPut("/{id:int}", async (int id, BookingInput? input, IBookingService service) =>
            await Safe(async () => input is null ? Invalid("Bokningsuppgifter saknas.") :
                Results.Ok(await service.UpdateAsync(id, input))));
        bookings.MapPost("/{id:int}/cancel", async (int id, IBookingService service) =>
            await Safe(async () => Results.Ok(await service.CancelAsync(id))));
        return app;
    }

    private static async Task<IResult> Safe(Func<Task<IResult>> operation)
    {
        try { return await operation(); }
        catch (BookingException ex)
        {
            return ex.Kind switch
            {
                BookingError.Validation => Results.ValidationProblem(new Dictionary<string, string[]>
                    { [ex.Field ?? "request"] = [ex.Message] }),
                BookingError.NotFound => Missing(ex.Message),
                _ => Results.Problem(title: "Konflikt", detail: ex.Message, statusCode: 409)
            };
        }
        catch
        {
            return Results.Problem(title: "Serverfel", detail: "Begäran kunde inte slutföras.", statusCode: 500);
        }
    }

    private static IResult Missing(string message) => Results.Problem(title: "Hittades inte", detail: message, statusCode: 404);
    private static IResult Invalid(string message) => Results.ValidationProblem(new Dictionary<string, string[]> { ["request"] = [message] });
}
