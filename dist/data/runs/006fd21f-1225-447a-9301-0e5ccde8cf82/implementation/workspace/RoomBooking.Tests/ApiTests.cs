using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using RoomBooking.Web.Contracts;

namespace RoomBooking.Tests;

public sealed class ApiTests : IClassFixture<BookingApiFactory>
{
    private readonly HttpClient client;
    public ApiTests(BookingApiFactory factory) => client = factory.CreateClient();

    [Fact]
    public async Task Rooms_and_missing_booking_have_expected_responses()
    {
        var rooms = await client.GetFromJsonAsync<RoomDto[]>("/api/rooms?activeOnly=true");
        Assert.NotNull(rooms);
        Assert.Equal(2, rooms.Length);
        var missing = await client.GetAsync("/api/bookings/999999");
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
        Assert.Equal("application/problem+json", missing.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task Create_filter_update_cancel_and_rebook()
    {
        var rooms = await client.GetFromJsonAsync<RoomDto[]>("/api/rooms?activeOnly=true");
        var room = rooms!.First(r => r.Name == "Beta");
        var start = DateTimeOffset.UtcNow.Date.AddDays(8).AddHours(10);
        var before = await client.GetFromJsonAsync<BookingDto[]>($"/api/bookings?roomId={room.Id}");
        Assert.Empty(before!);
        var input = new BookingInput { Title = "API möte", BookedBy = "Anna", RoomId = room.Id, StartTime = start, EndTime = start.AddHours(1) };
        var created = await client.PostAsJsonAsync("/api/bookings", input);
        Assert.True(created.StatusCode == HttpStatusCode.Created, await created.Content.ReadAsStringAsync());
        var booking = await created.Content.ReadFromJsonAsync<BookingDto>();
        Assert.Equal($"/api/bookings/{booking!.Id}", created.Headers.Location?.ToString());
        Assert.Equal(booking.Id, (await client.GetFromJsonAsync<BookingDto>($"/api/bookings/{booking.Id}"))!.Id);
        var filtered = await client.GetFromJsonAsync<BookingDto[]>($"/api/bookings?roomId={room.Id}&date={start:yyyy-MM-dd}&status=active");
        Assert.Contains(filtered!, b => b.Id == booking.Id);
        var overlap = await client.PostAsJsonAsync("/api/bookings", input);
        Assert.Equal(HttpStatusCode.Conflict, overlap.StatusCode);
        var adjacent = new BookingInput { Title = "Efter", BookedBy = "Anna", RoomId = room.Id, StartTime = start.AddHours(1), EndTime = start.AddHours(2) };
        Assert.Equal(HttpStatusCode.Created, (await client.PostAsJsonAsync("/api/bookings", adjacent)).StatusCode);
        input.Title = "Ändrat";
        Assert.Equal(HttpStatusCode.OK, (await client.PutAsJsonAsync($"/api/bookings/{booking.Id}", input)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsync($"/api/bookings/{booking.Id}/cancel", null)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsync($"/api/bookings/{booking.Id}/cancel", null)).StatusCode);
        Assert.Equal(HttpStatusCode.Created, (await client.PostAsJsonAsync("/api/bookings", input)).StatusCode);
    }

    [Fact]
    public async Task Invalid_values_have_validation_problem_and_no_internal_fields()
    {
        var start = DateTimeOffset.UtcNow.AddDays(9);
        var response = await client.PostAsJsonAsync("/api/bookings", new BookingInput { Title = "", BookedBy = "Anna", RoomId = 1, StartTime = start, EndTime = start });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        var content = await (await client.GetAsync("/api/bookings")).Content.ReadAsStringAsync();
        Assert.DoesNotContain("startUtc", content, StringComparison.OrdinalIgnoreCase);
        var malformed = await client.PostAsync("/api/bookings", new StringContent("{", System.Text.Encoding.UTF8, "application/json"));
        Assert.Equal(HttpStatusCode.BadRequest, malformed.StatusCode);
        Assert.Equal("application/problem+json", malformed.Content.Headers.ContentType?.MediaType);
    }
}

public sealed class BookingApiFactory : WebApplicationFactory<Program>
{
    private readonly string path = Path.Combine(Path.GetTempPath(), $"roombooking-api-{Guid.NewGuid():N}.db");
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Test");
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        { ["ConnectionStrings:RoomBooking"] = $"Data Source={path}" }));
    }
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        if (File.Exists(path)) File.Delete(path);
    }
}
