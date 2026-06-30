#WORKING WIPE!!!
# Runs in WinPE before Windows Setup applies the image.
# On "y": wipes disk 0 and builds the standard UEFI/GPT layout
#         (EFI / MSR / Windows / Recovery) so Setup can InstallTo disk 0,
#         partition 3 (Windows) unattended.
# On "n": does nothing and reboot 

function Initialize-Disk0 {
    do {
        write-host "This is only for Laptop!"
        $response = (Read-Host "Wipe disk and prepare for Windows install? (y/n)").ToLower()
        if ($response -notin 'y', 'n') {
            Write-Host "Please enter y or n" -ForegroundColor Red
        }
    } while ($response -notin 'y', 'n')

    if ($response -ne 'y') {
        Write-Host "No selected - the machine will now reboot." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        wpeutil reboot
        return
    }

    # Safety: confirm disk 0 is a fixed internal disk, not a USB / removable drive.
    $disk0 = Get-CimInstance Win32_DiskDrive -Filter "Index=0"
    if (-not $disk0 -or $disk0.InterfaceType -eq 'USB' -or $disk0.MediaType -match 'Removable') {
        Write-Host "Disk 0 is missing or looks like a USB/removable drive ($($disk0.Model))." -ForegroundColor Red
        Write-Host "Aborting to avoid wiping the wrong drive - the machine will now reboot." -ForegroundColor Yellow
        Start-Sleep -Seconds 4
        wpeutil reboot
        return
    }

    Write-Host "Wiping and partitioning disk 0..." -ForegroundColor Cyan
    Write-Host ""

    # EFI 300MB (FAT32, S:) / MSR 16MB / Windows (NTFS, W:, partition 3) /
    # Recovery (NTFS, R:, partition 4 with recovery type GUID + GPT attributes)
    $dpScript = @'
select disk 0
clean
convert gpt
create partition efi size=300
format quick fs=fat32 label="System"
assign letter=S
create partition msr size=16
create partition primary
shrink minimum=1000
format quick fs=ntfs label="Windows"
assign letter=W
create partition primary
format quick fs=ntfs label="Recovery"
assign letter=R
set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac"
gpt attributes=0x8000000000000001
'@

    $dptmp = "$env:TEMP\diskpart_disk0.txt"
    $dpScript | Out-File -Encoding ASCII $dptmp

    $proc = Start-Process diskpart -ArgumentList "/s `"$dptmp`"" -Wait -NoNewWindow -PassThru
    Remove-Item $dptmp -Force -ErrorAction SilentlyContinue

    Write-Host ""
    if ($proc.ExitCode -eq 0) {
        Write-Host "  [OK] Disk 0 wiped and partitioned (EFI / MSR / Windows / Recovery)" -ForegroundColor Green
        Write-Host "  Windows will install to disk 0, partition 3." -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] diskpart exited with code $($proc.ExitCode)" -ForegroundColor Yellow
        Write-Host "  Disk 0 may be in an incomplete state - check before continuing." -ForegroundColor Yellow
    }
    Write-Host ""
}

# Main execution

Initialize-Disk0
