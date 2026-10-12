using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SincronizadorPdf.Backend.Api.Transferencia.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PendingTransfers",
                columns: table => new
                {
                    Hash = table.Column<string>(type: "TEXT", nullable: false),
                    TargetDeviceId = table.Column<Guid>(type: "TEXT", nullable: false),
                    OriginDeviceId = table.Column<Guid>(type: "TEXT", nullable: false),
                    Content = table.Column<byte[]>(type: "BLOB", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PendingTransfers", x => new { x.Hash, x.TargetDeviceId });
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PendingTransfers");
        }
    }
}
