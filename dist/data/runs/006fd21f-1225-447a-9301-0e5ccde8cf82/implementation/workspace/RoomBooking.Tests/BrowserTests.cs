using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using Microsoft.Playwright;
using System.Net.Http.Json;
using RoomBooking.Web.Contracts;

namespace RoomBooking.Tests;

public sealed class BrowserTests
{
    [Fact]
    public async Task Booking_flow_works_in_chromium()
    {
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var port = ((IPEndPoint)listener.LocalEndpoint).Port;
        listener.Stop();
        var root = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../"));
        var webDir = Path.Combine(root, "RoomBooking.Web");
        var dbPath = Path.Combine(Path.GetTempPath(), $"roombooking-browser-{Guid.NewGuid():N}.db");
        var start = new ProcessStartInfo("dotnet", $"run --no-build --project \"{webDir}\" --urls http://127.0.0.1:{port}")
        {
            WorkingDirectory = root, UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true
        };
        start.Environment["ASPNETCORE_ENVIRONMENT"] = "Test";
        start.Environment["ConnectionStrings__RoomBooking"] = $"Data Source={dbPath}";
        using var server = Process.Start(start)!;
        try
        {
            using var http = new HttpClient();
            var ready = false;
            for (var i = 0; i < 80; i++)
            {
                if (server.HasExited) throw new InvalidOperationException(await server.StandardError.ReadToEndAsync());
                try { ready = (await http.GetAsync($"http://127.0.0.1:{port}/api/rooms")).IsSuccessStatusCode; }
                catch (HttpRequestException) { }
                if (ready) break;
                await Task.Delay(250);
            }
            Assert.True(ready, "Webbservern startade inte.");
            using var playwright = await Playwright.CreateAsync();
            var browserRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ms-playwright");
            var installed = Directory.Exists(browserRoot)
                ? Directory.GetDirectories(browserRoot, "chromium_headless_shell-*")
                    .Select(dir => Path.Combine(dir, "chrome-headless-shell-win64", "chrome-headless-shell.exe"))
                    .FirstOrDefault(File.Exists)
                : null;
            await using var browser = await playwright.Chromium.LaunchAsync(new() { Headless = true, ExecutablePath = installed });
            var page = await browser.NewPageAsync();
            await page.GotoAsync($"http://127.0.0.1:{port}/bookings");
            await Assertions.Expect(page.GetByRole(AriaRole.Heading, new() { Name = "Bokningar" })).ToBeVisibleAsync();
            await page.WaitForTimeoutAsync(500);
            await page.Locator("main").GetByRole(AriaRole.Link, new() { Name = "Skapa bokning" }).ClickAsync();
            await page.WaitForURLAsync("**/bookings/new");
            await Assertions.Expect(page.Locator("#title")).ToBeVisibleAsync();
            await page.Locator("#title").FocusAsync();
            await page.Keyboard.PressAsync("Tab");
            Assert.True(await page.Locator("#bookedBy").EvaluateAsync<bool>("element => element === document.activeElement"));
            await page.GetByRole(AriaRole.Button, new() { Name = "Spara bokning" }).ClickAsync();
            await Assertions.Expect(page.GetByText("Rubrik krävs.").First).ToBeVisibleAsync();
            await page.Locator("#title").FillAsync("Webbläsarmöte");
            await page.Locator("#bookedBy").FillAsync("Testperson");
            await page.Locator("#room").SelectOptionAsync(new SelectOptionValue { Label = "Beta (8 personer)" });
            var date = DateTime.UtcNow.Date.AddDays(14);
            await page.Locator("#date").FillAsync(date.ToString("yyyy-MM-dd"));
            await page.Locator("#start").FillAsync("13:00");
            await page.Locator("#end").FillAsync("14:00");
            await page.GetByRole(AriaRole.Button, new() { Name = "Spara bokning" }).ClickAsync();
            await Assertions.Expect(page.GetByText("Webbläsarmöte")).ToBeVisibleAsync();
            await page.GetByRole(AriaRole.Link, new() { Name = "Redigera" }).ClickAsync();
            await page.Locator("#title").FillAsync("Ändrat webbläsarmöte");
            await page.GetByRole(AriaRole.Button, new() { Name = "Spara bokning" }).ClickAsync();
            await Assertions.Expect(page.GetByText("Ändrat webbläsarmöte")).ToBeVisibleAsync();
            await page.GetByRole(AriaRole.Button, new() { Name = "Avboka", Exact = true }).ClickAsync();
            await page.GetByRole(AriaRole.Button, new() { Name = "Ja, avboka" }).ClickAsync();
            await Assertions.Expect(page.GetByText("Avbokad")).ToBeVisibleAsync();
            await page.GetByRole(AriaRole.Link, new() { Name = "Till bokningslistan" }).ClickAsync();
            await page.Locator("#filter-date").FillAsync(date.ToString("yyyy-MM-dd"));
            await Assertions.Expect(page.GetByRole(AriaRole.Link, new() { Name = "Ändrat webbläsarmöte" })).ToBeVisibleAsync();
            await page.Locator("main").GetByRole(AriaRole.Link, new() { Name = "Skapa bokning" }).ClickAsync();
            await page.Locator("#title").FillAsync("Ny bokning på fri tid");
            await page.Locator("#bookedBy").FillAsync("Testperson");
            await page.Locator("#room").SelectOptionAsync(new SelectOptionValue { Label = "Beta (8 personer)" });
            await page.Locator("#date").FillAsync(date.ToString("yyyy-MM-dd"));
            await page.Locator("#start").FillAsync("13:00");
            await page.Locator("#end").FillAsync("14:00");
            await page.GetByRole(AriaRole.Button, new() { Name = "Spara bokning" }).DblClickAsync();
            await Assertions.Expect(page.GetByText("Ny bokning på fri tid")).ToBeVisibleAsync();
            var all = await http.GetFromJsonAsync<BookingDto[]>($"http://127.0.0.1:{port}/api/bookings");
            Assert.Single(all!, booking => booking.Title == "Ny bokning på fri tid");
            await page.GotoAsync($"http://127.0.0.1:{port}/bookings/999999");
            await Assertions.Expect(page.GetByText("Bokningen finns inte.")).ToBeVisibleAsync();
        }
        finally
        {
            if (!server.HasExited) { server.Kill(entireProcessTree: true); await server.WaitForExitAsync(); }
            Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
            for (var attempt = 0; attempt < 20 && File.Exists(dbPath); attempt++)
            {
                try { File.Delete(dbPath); }
                catch (IOException) { await Task.Delay(100); }
            }
        }
    }
}
