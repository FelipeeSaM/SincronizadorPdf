using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SincronizadorPdf.Backend.Api.Transferencia.Migrations
{
    /// <inheritdoc />
    public partial class AddNameToPendingTransfer : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Name",
                table: "PendingTransfers",
                type: "TEXT",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Name",
                table: "PendingTransfers");
        }
    }
}
