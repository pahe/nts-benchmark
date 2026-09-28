using Bunit;
using Microsoft.Extensions.DependencyInjection;
using RoomBooking.Web.Components.Pages;
using RoomBooking.Web.Contracts;
using RoomBooking.Web.Services;

namespace RoomBooking.Tests;

public sealed class ComponentTests : TestContext
{
    [Fact]
    public void Booking_list_shows_empty_state_and_filters()
    {
        Services.AddSingleton<IBookingService>(new EmptyService());
        var page = RenderComponent<Bookings>();
        Assert.Contains("Inga bokningar", page.Markup);
        Assert.Contains("filter-room", page.Markup);
        Assert.Contains("filter-date", page.Markup);
    }

    [Fact]
    public void Create_form_shows_field_validation()
    {
        Services.AddSingleton<IBookingService>(new EmptyService());
        var page = RenderComponent<CreateBooking>();
        page.Find("#title").Change("");
        page.Find("button[type=submit]").Click();
        Assert.Contains("Rubrik krävs", page.Markup);
    }

    private sealed class EmptyService : IBookingService
    {
        public Task<IReadOnlyList<RoomDto>> GetRoomsAsync(bool activeOnly = false) => Task.FromResult<IReadOnlyList<RoomDto>>([new(1, "Alfa", 4, true)]);
        public Task<IReadOnlyList<BookingDto>> GetBookingsAsync(BookingFilter filter) => Task.FromResult<IReadOnlyList<BookingDto>>([]);
        public Task<BookingDto?> GetBookingAsync(int id) => Task.FromResult<BookingDto?>(null);
        public Task<BookingDto> CreateAsync(BookingInput input) => throw new NotImplementedException();
        public Task<BookingDto> UpdateAsync(int id, BookingInput input) => throw new NotImplementedException();
        public Task<BookingDto> CancelAsync(int id) => throw new NotImplementedException();
    }
}
