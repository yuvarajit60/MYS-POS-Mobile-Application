using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IVehicleService
{
    Task<IReadOnlyList<VehicleDto>> SearchAsync(string? search);
}

/// <summary>Global, not location-scoped — matches CustomerService/ProductService's SearchAsync convention.</summary>
public class VehicleService : IVehicleService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public VehicleService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<VehicleDto>> SearchAsync(string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<VehicleDto>(
            """
            SELECT TOP 50 VEHICLEID AS VehicleId, ISNULL(VEHICLENAME, '') AS VehicleName
            FROM VEHICLE
            WHERE STATUS = 1
              AND (@Search IS NULL OR VEHICLENAME LIKE @Like)
            ORDER BY VEHICLENAME
            """,
            new { Search = search, Like = like });

        return rows.ToList();
    }
}
