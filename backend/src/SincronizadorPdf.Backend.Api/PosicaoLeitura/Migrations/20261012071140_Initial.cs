using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SincronizadorPdf.Backend.Api.PosicaoLeitura.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ReadingPositions",
                columns: table => new
                {
                    Hash = table.Column<string>(type: "TEXT", nullable: false),
                    DeviceId = table.Column<Guid>(type: "TEXT", nullable: false),
                    Page = table.Column<int>(type: "INTEGER", nullable: false),
                    ScrollPercentage = table.Column<double>(type: "REAL", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ReadingPositions", x => x.Hash);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ReadingPositions");
        }
    }
}
