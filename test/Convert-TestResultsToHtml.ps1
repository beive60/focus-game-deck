<#
.SYNOPSIS
    Convert NUnit XML test results to HTML report

.DESCRIPTION
    Converts test-results.xml to a readable HTML report using XSLT transformation
#>

param(
    [string]$InputXml = "$PSScriptRoot/test-results.xml",
    [string]$OutputHtml = "$PSScriptRoot/test-results.html"
)

$ErrorActionPreference = "Stop"

# XSLT definition for HTML conversion
$xslt = @"
<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="html" indent="yes" encoding="utf-8"/>

    <xsl:template match="/test-results">
        <html>
            <head>
                <title>Focus Game Deck Test Results</title>
                <style>
                    body {
                        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                        margin: 20px;
                        background-color: #f5f5f5;
                    }
                    h1 {
                        color: #333;
                        border-bottom: 3px solid #4CAF50;
                        padding-bottom: 10px;
                    }
                    .summary {
                        background-color: white;
                        padding: 20px;
                        border-radius: 8px;
                        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                        margin-bottom: 20px;
                    }
                    .summary-grid {
                        display: grid;
                        grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
                        gap: 15px;
                        margin-top: 15px;
                    }
                    .metric {
                        padding: 15px;
                        border-radius: 5px;
                        text-align: center;
                    }
                    .metric-label {
                        font-size: 12px;
                        color: #666;
                        text-transform: uppercase;
                    }
                    .metric-value {
                        font-size: 32px;
                        font-weight: bold;
                        margin-top: 5px;
                    }
                    .total { background-color: #e3f2fd; color: #1976d2; }
                    .passed { background-color: #e8f5e9; color: #388e3c; }
                    .failed { background-color: #ffebee; color: #d32f2f; }
                    .skipped { background-color: #fff3e0; color: #f57c00; }
                    .test-suite {
                        background-color: white;
                        margin-bottom: 15px;
                        border-radius: 8px;
                        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                        overflow: hidden;
                    }
                    .test-suite .test-suite {
                        margin-left: 20px;
                        margin-bottom: 10px;
                        border-left: 3px solid #e0e0e0;
                        box-shadow: none;
                        border-radius: 4px;
                    }
                    .test-suite .test-suite .test-suite {
                        margin-left: 20px;
                        border-left: 2px solid #f0f0f0;
                    }
                    .suite-header {
                        padding: 15px;
                        background-color: #f8f9fa;
                        cursor: pointer;
                        border-left: 4px solid #4CAF50;
                    }
                    .test-suite .test-suite .suite-header {
                        padding: 10px 15px;
                        background-color: #fafafa;
                        border-left: 3px solid #4CAF50;
                        font-size: 14px;
                    }
                    .test-suite .test-suite .test-suite .suite-header {
                        padding: 8px 15px;
                        background-color: #fcfcfc;
                        border-left: 2px solid #4CAF50;
                        font-size: 13px;
                    }
                    .suite-header.failure {
                        border-left-color: #f44336;
                    }
                    .suite-name {
                        font-weight: bold;
                        font-size: 16px;
                        color: #333;
                    }
                    .suite-stats {
                        font-size: 12px;
                        color: #666;
                        margin-top: 5px;
                    }
                    .test-case {
                        padding: 12px 15px;
                        border-bottom: 1px solid #eee;
                        margin-left: 20px;
                    }
                    .test-case:last-child {
                        border-bottom: none;
                    }
                    .test-name {
                        font-weight: 500;
                        margin-bottom: 5px;
                    }
                    .test-status {
                        display: inline-block;
                        padding: 3px 8px;
                        border-radius: 3px;
                        font-size: 11px;
                        font-weight: bold;
                        text-transform: uppercase;
                        margin-right: 10px;
                    }
                    .status-success {
                        background-color: #4CAF50;
                        color: white;
                    }
                    .status-failure {
                        background-color: #f44336;
                        color: white;
                    }
                    .status-ignored {
                        background-color: #ff9800;
                        color: white;
                    }
                    .test-time {
                        color: #666;
                        font-size: 12px;
                    }
                    .failure-message {
                        background-color: #ffebee;
                        padding: 10px;
                        margin-top: 10px;
                        border-radius: 4px;
                        border-left: 3px solid #f44336;
                        font-family: 'Consolas', 'Courier New', monospace;
                        font-size: 12px;
                        white-space: pre-wrap;
                        word-wrap: break-word;
                    }
                    .stack-trace {
                        background-color: #f5f5f5;
                        padding: 10px;
                        margin-top: 5px;
                        border-radius: 4px;
                        font-family: 'Consolas', 'Courier New', monospace;
                        font-size: 11px;
                        color: #666;
                        max-height: 200px;
                        overflow-y: auto;
                    }
                    .environment {
                        background-color: white;
                        padding: 15px;
                        border-radius: 8px;
                        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                        margin-bottom: 20px;
                        font-size: 13px;
                        color: #666;
                    }

                    /* Dark mode support */
                    @media (prefers-color-scheme: dark) {
                        body {
                            background-color: #1a1a1a;
                        }
                        h1 {
                            color: #e0e0e0;
                            border-bottom-color: #66bb6a;
                        }
                        h2 {
                            color: #e0e0e0;
                        }
                        .summary, .environment {
                            background-color: #2d2d2d;
                            color: #e0e0e0;
                        }
                        .environment h3 {
                            color: #e0e0e0;
                        }
                        .metric {
                            background-color: #333;
                        }
                        .metric-label {
                            color: #b0b0b0;
                        }
                        .total { background-color: #1e3a5f; color: #64b5f6; }
                        .passed { background-color: #1b5e20; color: #81c784; }
                        .failed { background-color: #7f0000; color: #e57373; }
                        .skipped { background-color: #4e342e; color: #ffb74d; }
                        .test-suite {
                            background-color: #2d2d2d;
                        }
                        .test-suite .test-suite {
                            border-left-color: #404040;
                        }
                        .test-suite .test-suite .test-suite {
                            border-left-color: #505050;
                        }
                        .suite-header {
                            background-color: #3a3a3a;
                            color: #e0e0e0;
                            border-left-color: #66bb6a;
                        }
                        .test-suite .test-suite .suite-header {
                            background-color: #333;
                        }
                        .test-suite .test-suite .test-suite .suite-header {
                            background-color: #2d2d2d;
                        }
                        .suite-header.failure {
                            border-left-color: #ef5350;
                        }
                        .suite-name {
                            color: #e0e0e0;
                        }
                        .suite-stats {
                            color: #b0b0b0;
                        }
                        .test-case {
                            border-bottom-color: #404040;
                            background-color: #2d2d2d;
                        }
                        .test-name {
                            color: #e0e0e0;
                        }
                        .test-time {
                            color: #b0b0b0;
                        }
                        .failure-message {
                            background-color: #3d1f1f;
                            border-left-color: #ef5350;
                            color: #e0e0e0;
                        }
                        .stack-trace {
                            background-color: #2d2d2d;
                            color: #b0b0b0;
                        }
                    }
                </style>
            </head>
            <body>
                <h1>Focus Game Deck Test Results</h1>

                <div class="summary">
                    <h2>Summary</h2>
                    <div class="summary-grid">
                        <div class="metric total">
                            <div class="metric-label">Total Tests</div>
                            <div class="metric-value"><xsl:value-of select="@total"/></div>
                        </div>
                        <div class="metric passed">
                            <div class="metric-label">Passed</div>
                            <div class="metric-value"><xsl:value-of select="@total - @failures - @skipped"/></div>
                        </div>
                        <div class="metric failed">
                            <div class="metric-label">Failed</div>
                            <div class="metric-value"><xsl:value-of select="@failures"/></div>
                        </div>
                        <div class="metric skipped">
                            <div class="metric-label">Skipped</div>
                            <div class="metric-value"><xsl:value-of select="@skipped"/></div>
                        </div>
                    </div>
                    <p style="margin-top: 15px;">
                        <strong>Date:</strong> <xsl:value-of select="@date"/> <xsl:value-of select="@time"/><br/>
                        <strong>Duration:</strong> <xsl:value-of select="test-suite/@time"/> seconds
                    </p>
                </div>

                <div class="environment">
                    <h3>Environment</h3>
                    <strong>Platform:</strong> <xsl:value-of select="environment/@platform"/><br/>
                    <strong>Machine:</strong> <xsl:value-of select="environment/@machine-name"/><br/>
                    <strong>User:</strong> <xsl:value-of select="environment/@user-domain"/>\<xsl:value-of select="environment/@user"/><br/>
                    <strong>OS Version:</strong> <xsl:value-of select="environment/@os-version"/><br/>
                    <strong>CLR Version:</strong> <xsl:value-of select="environment/@clr-version"/>
                </div>

                <h2>Test Suites</h2>
                <xsl:apply-templates select="test-suite/results/test-suite"/>
            </body>
        </html>
    </xsl:template>

    <xsl:template match="test-suite[@type='TestFixture']">
        <xsl:if test="@executed='True'">
            <div class="test-suite">
                <div class="suite-header">
                    <xsl:if test="@result='Failure'">
                        <xsl:attribute name="class">suite-header failure</xsl:attribute>
                    </xsl:if>
                    <div class="suite-name">
                        <xsl:value-of select="substring-after(@name, 'focus-game-deck\test\pester\')"/>
                        <xsl:if test="not(contains(@name, 'pester'))">
                            <xsl:value-of select="@name"/>
                        </xsl:if>
                    </div>
                    <div class="suite-stats">
                        Time: <xsl:value-of select="format-number(@time, '0.00')"/>s |
                        Result: <xsl:value-of select="@result"/>
                    </div>
                </div>
                <xsl:apply-templates select="results/*"/>
            </div>
        </xsl:if>
    </xsl:template>

    <xsl:template match="test-case">
        <xsl:if test="@executed='True' or @executed='False'">
            <div class="test-case">
                <div class="test-name">
                    <span class="test-status">
                        <xsl:choose>
                            <xsl:when test="@result='Success'">
                                <xsl:attribute name="class">test-status status-success</xsl:attribute>
                                ✓ PASS
                            </xsl:when>
                            <xsl:when test="@result='Failure'">
                                <xsl:attribute name="class">test-status status-failure</xsl:attribute>
                                ✗ FAIL
                            </xsl:when>
                            <xsl:when test="@result='Ignored'">
                                <xsl:attribute name="class">test-status status-ignored</xsl:attribute>
                                ⊘ SKIP
                            </xsl:when>
                        </xsl:choose>
                    </span>
                    <span class="test-time">(<xsl:value-of select="format-number(@time, '0.000')"/>s)</span>
                    <br/>
                    <xsl:value-of select="@description"/>
                </div>
                <xsl:if test="failure">
                    <div class="failure-message">
                        <strong>Error:</strong>
                        <xsl:value-of select="failure/message"/>
                    </div>
                    <xsl:if test="failure/stack-trace">
                        <div class="stack-trace">
                            <xsl:value-of select="failure/stack-trace"/>
                        </div>
                    </xsl:if>
                </xsl:if>
            </div>
        </xsl:if>
    </xsl:template>
</xsl:stylesheet>
"@

try {
    Write-Host "Converting test results to HTML..." -ForegroundColor Cyan

    # Save XSLT file temporarily
    $xsltPath = Join-Path $env:TEMP "test-results-transform.xslt"
    $xslt | Out-File -FilePath $xsltPath -Encoding UTF8

    # XML transformation
    $xmlDoc = New-Object System.Xml.XmlDocument
    $xmlDoc.Load($InputXml)

    $xsltDoc = New-Object System.Xml.Xsl.XslCompiledTransform
    $xsltDoc.Load($xsltPath)

    $xsltDoc.Transform($InputXml, $OutputHtml)

    # Cleanup
    Remove-Item $xsltPath -Force

    Write-Host "[OK] HTML report generated: $OutputHtml" -ForegroundColor Green
    Write-Host "Opening in browser..." -ForegroundColor Cyan

    # Open the generated HTML report
    Start-Process $OutputHtml
} catch {
    Write-Host "[ERROR] Failed to convert XML to HTML: $_" -ForegroundColor Red
    exit 1
}
