param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

function Read-Utf8([string]$Path) {
    return [System.IO.File]::ReadAllText($Path)
}

function Write-Utf8([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Replace-Once(
    [string]$Text,
    [string]$Old,
    [string]$New,
    [string]$Label
) {
    $first = $Text.IndexOf($Old)

    if ($first -lt 0) {
        throw "Could not find expected code for: $Label. Nothing was written."
    }

    $second = $Text.IndexOf($Old, $first + $Old.Length)

    if ($second -ge 0) {
        throw "Found more than one match for: $Label. Nothing was written."
    }

    return $Text.Substring(0, $first) +
        $New +
        $Text.Substring($first + $Old.Length)
}

$staffPath = Join-Path $ProjectRoot "lib/pages/dashboard/staff_dashboard.dart"
$animalPath = Join-Path $ProjectRoot "lib/pages/animal_records_page.dart"

if (-not (Test-Path $staffPath)) {
    throw "Missing file: $staffPath"
}

if (-not (Test-Path $animalPath)) {
    throw "Missing file: $animalPath"
}

# Read both files first.
$staffOriginal = Read-Utf8 $staffPath
$animalOriginal = Read-Utf8 $animalPath

$staff = $staffOriginal
$animal = $animalOriginal

# ============================================================================
# STAFF DASHBOARD
# ============================================================================

$oldStaffHeight = @'
        else
          SizedBox(
            height: 300,
            child: Row(
'@

$newStaffHeight = @'
        else
          SizedBox(
            height: 320,
            child: Row(
'@

$staff = Replace-Once `
    $staff `
    $oldStaffHeight `
    $newStaffHeight `
    "Staff Dashboard Stock Priority row height"

$oldPriorityHelper = @'
              Text(
                helper,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.mutedForeground,
                ),
              ),
'@

$newPriorityHelper = @'
              Text(
                helper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.mutedForeground,
                ),
              ),
'@

$staff = Replace-Once `
    $staff `
    $oldPriorityHelper `
    $newPriorityHelper `
    "Stock Priority Critical/High/Medium helper text"

# ============================================================================
# MANAGER ANIMAL RECORDS
# ============================================================================

$oldStatusField = @'
                          // ===================================================
                          // STATUS
                          // ===================================================

                          if (isEdit) ...[
                            const SizedBox(height: 12),

                            AppDropdownField<PetStatus>(
                              label: 'Status',
                              initialValue: status,
                              options:
                                  PetStatus.values.map(
                                (value) {
                                  return AppDropdownOption(
                                    value,
                                    _statusMeta(value).$1,
                                  );
                                },
                              ).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  status = value;
                                });
                              },
                            ),
                          ],

                          const SizedBox(height: 8),
'@

$newStatusField = @'
                          // ===================================================
                          // STATUS
                          // ===================================================

                          const SizedBox(height: 12),

                          AppDropdownField<PetStatus>(
                            label: 'Status',
                            initialValue: status,
                            options:
                                PetStatus.values.map(
                              (value) {
                                return AppDropdownOption(
                                  value,
                                  _statusMeta(value).$1,
                                );
                              },
                            ).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                status = value;
                              });
                            },
                          ),

                          const SizedBox(height: 8),
'@

$animal = Replace-Once `
    $animal `
    $oldStatusField `
    $newStatusField `
    "Add Animal Status field"

$oldCreatePet = @'
                              await _service.createPet(
                                petName: cleanName,
                                species: species,
                                gender: gender,
                                breed: cleanBreed,
                                owner: cleanOwner,
                                spayedNeutered:
                                    spayedNeutered,
                              );
'@

$newCreatePet = @'
                              await _service.createPet(
                                petName: cleanName,
                                species: species,
                                gender: gender,
                                status: status,
                                breed: cleanBreed,
                                owner: cleanOwner,
                                spayedNeutered:
                                    spayedNeutered,
                              );
'@

$animal = Replace-Once `
    $animal `
    $oldCreatePet `
    $newCreatePet `
    "Saving selected Status for a new animal"

# ============================================================================
# WRITE ONLY AFTER EVERY CHECK PASSES
# ============================================================================

Write-Utf8 $staffPath $staff
Write-Utf8 $animalPath $animal

Write-Host ""
Write-Host "SUCCESS"
Write-Host "Updated: lib/pages/dashboard/staff_dashboard.dart"
Write-Host "Updated: lib/pages/animal_records_page.dart"
Write-Host ""
Write-Host "You can now delete apply_small_panel_revisions.ps1 if you want."