param(
  [Parameter(Mandatory = $true)][string]$ReportPath,
  [int]$ExpectedCases = 4
)
$ErrorActionPreference = 'Stop'
$resolvedReport = (Resolve-Path -LiteralPath $ReportPath).Path
$excelApp = $null
$reportBook = $null
$reportSheets = $null
try {
  # New, invisible instance. Do not attach to the user's existing Excel window.
  $excelApp = New-Object -ComObject Excel.Application
  $excelApp.Visible = $false
  $excelApp.DisplayAlerts = $false
  $excelApp.AutomationSecurity = 3
  # UpdateLinks=0, ReadOnly=true, CorruptLoad=xlNormalLoad (0).
  # Omitted CorruptLoad defaults to xlNormalLoad for automation.
  $reportBook = $excelApp.Workbooks.Open($resolvedReport, 0, $true)
  $reportSheets = $reportBook.Worksheets
  if ($reportSheets.Count -ne 3) { throw 'Expected three report sheets.' }
  foreach ($name in @('Summary', 'Evaluations', 'By Module')) {
    $sheet = $reportSheets.Item($name)
    $range = $null
    try {
      $range = $sheet.UsedRange
      if ($name -eq 'Evaluations' -and $range.Rows.Count -ne ($ExpectedCases + 1)) {
        throw 'Excel did not retain all exported Test Case rows.'
      }
      Write-Output "$name : $($range.Rows.Count) rows"
    } finally {
      if ($null -ne $range) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($range) }
      [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($sheet)
    }
  }
  Write-Output 'Microsoft Excel compatibility PASS: normal-load, read-only open passed.'
} finally {
  if ($null -ne $reportSheets) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($reportSheets) }
  if ($null -ne $reportBook) {
    $reportBook.Close($false)
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($reportBook)
  }
  if ($null -ne $excelApp) {
    $excelApp.Quit()
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($excelApp)
  }
}
