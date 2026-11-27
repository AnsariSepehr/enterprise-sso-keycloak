<#
.SYNOPSIS
  Read-only inventory of an on-premises Exchange server, used to decide whether SSO is possible.
.DESCRIPTION
  Run it in the EXCHANGE MANAGEMENT SHELL. In a plain Windows PowerShell window the Exchange
  cmdlets do not exist and every command fails with "not recognized" - which says nothing about
  the server. Changes nothing. docs/services/exchange.md
#>
$ErrorActionPreference = 'Stop'

if (-not (Get-Command Get-ExchangeServer -ErrorAction SilentlyContinue)) {
    Write-Error 'Get-ExchangeServer not found. Open the Exchange Management Shell, not a plain PowerShell window.'
}

Write-Host "`n== Servers, edition and build ==" -ForegroundColor Cyan
Get-ExchangeServer | Format-List Name, Edition, AdminDisplayVersion, ServerRole

Write-Host "`n== Outlook on the web (OWA): URLs and authentication methods ==" -ForegroundColor Cyan
Get-OwaVirtualDirectory | Format-List Server, InternalUrl, ExternalUrl, FormsAuthentication, WindowsAuthentication, BasicAuthentication

Write-Host "`n== Exchange Control Panel (ECP) ==" -ForegroundColor Cyan
Get-EcpVirtualDirectory | Format-List Server, InternalUrl, ExternalUrl, FormsAuthentication, WindowsAuthentication, BasicAuthentication

Write-Host "`n== OAuth / modern authentication ==" -ForegroundColor Cyan
Get-AuthConfig | Format-List CurrentCertificateThumbprint, ServiceName, Realm
Get-AuthServer -ErrorAction SilentlyContinue | Format-List Name, Type, IssuerIdentifier, Enabled

$build = (Get-ExchangeServer | Select-Object -First 1).AdminDisplayVersion
Write-Host "`nHow to read this" -ForegroundColor Yellow
Write-Host "  Version 15.1 = Exchange 2016: no modern authentication, so no AD FS route."
Write-Host "  Version 15.2 = Exchange 2019 (needs CU13 or later) or Subscription Edition: an AD FS route exists."
Write-Host "  Detected: $build"
