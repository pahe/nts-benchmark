using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Diagnostics;
using RoomBooking.Web.Api;
using RoomBooking.Web.Components;
using RoomBooking.Web.Data;
using RoomBooking.Web.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();
builder.Services.AddDbContextFactory<RoomBookingDbContext>((services, options) =>
    options.UseSqlite(services.GetRequiredService<IConfiguration>().GetConnectionString("RoomBooking") ?? "Data Source=roombooking.db"));
builder.Services.AddScoped<IBookingService, BookingService>();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddProblemDetails();
var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
builder.Services.AddCors(options => options.AddPolicy("configured", policy =>
    policy.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();
using (var scope = app.Services.CreateScope())
{
    var factory = scope.ServiceProvider.GetRequiredService<IDbContextFactory<RoomBookingDbContext>>();
    await using var db = await factory.CreateDbContextAsync();
    await DatabaseSeeder.SeedAsync(db);
}

app.UseExceptionHandler(new ExceptionHandlerOptions
{
    StatusCodeSelector = exception => exception is BadHttpRequestException badRequest ? badRequest.StatusCode : 500
});
if (app.Environment.IsDevelopment() || app.Environment.IsEnvironment("Test"))
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    app.UseHsts();
}
app.UseWhen(context => !context.Request.Path.StartsWithSegments("/api"), branch =>
    branch.UseStatusCodePagesWithReExecute("/not-found", createScopeForStatusCodePages: true));
app.Use(async (context, next) =>
{
    await next();
    if (context.Request.Path.StartsWithSegments("/api") && context.Response.StatusCode >= 400 &&
        !context.Response.HasStarted && context.Response.ContentType is null)
    {
        await Results.Problem(title: "Begäran kunde inte behandlas", statusCode: context.Response.StatusCode)
            .ExecuteAsync(context);
    }
});
app.UseHttpsRedirection();
app.UseCors("configured");
app.UseAntiforgery();
app.MapBookingApi();
app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();

public partial class Program;
