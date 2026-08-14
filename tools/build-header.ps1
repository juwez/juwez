#Requires -Version 7
<#
    Emits assets/header-light.svg and assets/header-dark.svg.
    Both files share one geometry pass so the two themes can never drift.
#>

$ErrorActionPreference = 'Stop'

# 5x7 cell per glyph, rows top to bottom. Only the five letters in the name exist.
# Uppercase forms: at this dot count lowercase bowls collapse into blobs.
$Glyphs = [ordered]@{
    J = @('00111', '00010', '00010', '00010', '00010', '10010', '01100')
    U = @('10001', '10001', '10001', '10001', '10001', '10001', '01110')
    W = @('10001', '10001', '10001', '10101', '10101', '11011', '10001')
    E = @('11111', '10000', '10000', '11110', '10000', '10000', '11111')
    Z = @('11111', '00001', '00010', '00100', '01000', '10000', '11111')
}

$Width, $Height = 1100, 300
$Pitch, $Radius = 20, 7.5
$OriginX, $OriginY = 72, 86
$RightEdge = 1028

$Themes = @(
    [pscustomobject]@{
        Name = 'dark'
        Bg = '#16130D'; Rule = '#2A2418'; Tick = '#3A3121'
        Amber = '#FFB020'; Ink = '#EDE6D8'; Muted = '#8A7F6B'
        Dot = '#FFB020'
    }
    [pscustomobject]@{
        # Amber on a pale ground goes muddy, so light mode plots the name in ink
        # and keeps amber for the signal accents only.
        Name = 'light'
        Bg = '#E4E8EA'; Rule = '#D0D8DC'; Tick = '#B9C4CA'
        Amber = '#B05F00'; Ink = '#151A1F'; Muted = '#5A666E'
        Dot = '#1B2228'
    }
)

$dots = [System.Collections.Generic.List[object]]::new()
$column = 0
foreach ($letter in $Glyphs.Keys) {
    $rows = $Glyphs[$letter]
    for ($x = 0; $x -lt 5; $x++) {
        for ($y = 0; $y -lt 7; $y++) {
            if ($rows[$y][$x] -eq '1') {
                $dots.Add([pscustomobject]@{
                    Cx  = $OriginX + ($column + $x) * $Pitch
                    Cy  = $OriginY + $y * $Pitch
                    Col = $column + $x
                })
            }
        }
    }
    $column += 6   # 5 columns of glyph plus one of air
}

$matrixRight = ($dots | Measure-Object -Property Cx -Maximum).Maximum
$matrixSpan = $matrixRight - $OriginX + $Pitch
$matrixBottom = $OriginY + 6 * $Pitch

foreach ($theme in $Themes) {
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("<svg xmlns=`"http://www.w3.org/2000/svg`" viewBox=`"0 0 $Width $Height`" width=`"$Width`" height=`"$Height`" role=`"img`" aria-label=`"juwez`">")

    # Dots default to lit so the banner is still correct when CSS animation never runs.
    $delays = ($dots.Col | Sort-Object -Unique | ForEach-Object {
        "    .k$_{animation-delay:$([math]::Round($_ * 0.03, 3))s}"
    }) -join "`n"

    $null = $sb.AppendLine(@"
  <style>
    .rule{stroke:$($theme.Rule);stroke-width:1}
    .tick{stroke:$($theme.Tick);stroke-width:1.5}
    .dot{fill:$($theme.Dot);animation:lite .38s ease-out backwards}
    .mono{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:13px;letter-spacing:.16em}
    .muted{fill:$($theme.Muted)}
    .ink{fill:$($theme.Ink)}
    .amber{fill:$($theme.Amber)}
    @keyframes lite{from{opacity:0}to{opacity:1}}
    @keyframes sweep{
      0%{transform:translateX(0);opacity:0}
      10%{opacity:.85}
      90%{opacity:.85}
      100%{transform:translateX(${matrixSpan}px);opacity:0}
    }
    .scan{animation:sweep 1.05s ease-out forwards}
    @media (prefers-reduced-motion: reduce){
      .dot{animation:none}
      .scan{display:none}
    }
$delays
  </style>
  <rect width="$Width" height="$Height" fill="$($theme.Bg)"/>
"@)

    # Measurement axis along the bottom. No chart rules behind the name: they read
    # as strikethroughs where they cross the dot rows.
    $null = $sb.AppendLine('  <g class="tick">')
    for ($x = 72; $x -le $RightEdge; $x += 16) {
        $tall = (($x - 72) % 96) -eq 0
        $y2 = if ($tall) { 278 } else { 272 }
        $null = $sb.AppendLine("    <line x1=`"$x`" y1=`"266`" x2=`"$x`" y2=`"$y2`"/>")
    }
    $null = $sb.AppendLine('  </g>')

    $null = $sb.AppendLine("  <text x=`"72`" y=`"56`" class=`"mono amber`">CH 01</text>")
    $null = $sb.AppendLine("  <text x=`"150`" y=`"56`" class=`"mono muted`">RECORDING SINCE 2018</text>")

    $null = $sb.AppendLine('  <g>')
    foreach ($dot in $dots) {
        $null = $sb.AppendLine("    <circle class=`"dot k$($dot.Col)`" cx=`"$($dot.Cx)`" cy=`"$($dot.Cy)`" r=`"$Radius`"/>")
    }
    $null = $sb.AppendLine('  </g>')

    $null = $sb.AppendLine("  <rect class=`"scan`" x=`"$($OriginX - 15)`" y=`"$($OriginY - 18)`" width=`"2`" height=`"$($matrixBottom - $OriginY + 36)`" fill=`"$($theme.Amber)`"/>")

    # Readout, right-aligned so the composition closes at the same edge as the axis.
    $rows = @(
        @('ROLE', 'BACKEND'),
        @('STACK', '.NET  ·  NODE.JS')
    )
    $labelX = $RightEdge - 260
    $y = 128
    foreach ($row in $rows) {
        $null = $sb.AppendLine("  <text x=`"$labelX`" y=`"$y`" class=`"mono muted`">$($row[0])</text>")
        $null = $sb.AppendLine("  <text x=`"$RightEdge`" y=`"$y`" text-anchor=`"end`" class=`"mono ink`">$($row[1])</text>")
        $y += 30
    }

    # Too long for a right-aligned panel row, so it runs full width under the name.
    $focus = 'SCALABLE SYSTEMS  ·  ARCHITECTURE  ·  AI  ·  GOOD OLD FASHIONED CODING'
    $null = $sb.AppendLine("  <text x=`"72`" y=`"240`" class=`"mono ink`">$focus</text>")

    $null = $sb.AppendLine('</svg>')

    $dir = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText((Join-Path $dir "header-$($theme.Name).svg"), $sb.ToString())
    Write-Host "wrote header-$($theme.Name).svg"
}
