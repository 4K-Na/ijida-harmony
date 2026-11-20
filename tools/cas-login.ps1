#Requires -Version 5.1
<#
.SYNOPSIS
    i集大 CAS 登录工具（照搬原程序流程），只输出 idToken，不落盘凭据。
.DESCRIPTION
    流程：GET /cas/login -> 取 execution + JSESSIONID
          GET /cas/jwt/publicKey -> RSA2048 公钥
          RSA PKCS1 v1.5 加密密码 -> "__RSA__"+base64
          POST /cas/mfa/detect -> need / state
          POST /cas/login -> 302 Location ?ticket=<JWT>
          ticket.payload.idToken => App userToken
.PARAMETER User
    学号 / 工号
.PARAMETER Pass
    密码（明文传入，仅用于本次请求）
.PARAMETER ShowLog
    打印每步状态到 stderr
.EXAMPLE
    $tok = & .\cas-login.ps1 -User <学号> -Pass *** -ShowLog
    curl.exe -H "X-id-token: $tok" https://authx-service.paas.jmu.edu.cn/personal/api/v1/personal/me/user
#>
param(
    [Parameter(Mandatory = $true)][string] $User,
    [Parameter(Mandatory = $true)][string] $Pass,
    [switch] $ShowLog
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$CAS = 'https://cas.paas.jmu.edu.cn'
$SERVICE = 'https://superapp.paas.jmu.edu.cn/'
$UA = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 uni-app'
$tmp = Join-Path $env:TEMP ('ijida_cas_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$cj = Join-Path $tmp 'cj.txt'

function Log([string]$m) { if ($ShowLog) { Write-Host "[cas] $m" } }
function Dec-B64Url([string]$s) {
    $p = $s.Replace('-', '+').Replace('_', '/')
    switch ($p.Length % 4) { 2 { $p += '==' } 3 { $p += '=' } }
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p))
}

try {
    $loginUrl = "$CAS/cas/login?service=" + [uri]::EscapeDataString($SERVICE)
    $r1 = (curl.exe -s -i -c $cj -A $UA "$loginUrl") -join "`n"
    # 已有 SSO 会话时直接 302 带 ticket
    $loc0 = ([regex]::Match($r1, '(?im)^location:\s*(.+)$')).Groups[1].Value.Trim()
    if ($loc0 -match 'ticket=') {
        Log 'SSO 会话有效，直接拿到 ticket'
        $ticket = [uri]::UnescapeDataString(([regex]::Match($loc0, 'ticket=([^&\s]+)')).Groups[1].Value)
        return ((Dec-B64Url ($ticket.Split('.')[1]) | ConvertFrom-Json).idToken)
    }

    $exec = ([regex]::Match($r1, 'name="execution"\s+value="([^"]*)"')).Groups[1].Value
    if (-not $exec) { throw 'CAS 登录页未找到 execution 字段' }
    Log "execution=$exec"

    $pem = curl.exe -s -b $cj -A $UA "$CAS/cas/jwt/publicKey"
    $b64 = ($pem -replace '-----BEGIN PUBLIC KEY-----', '' -replace '-----END PUBLIC KEY-----', '' -replace '\s', '')
    $rsa = [System.Security.Cryptography.RSA]::Create()
    $rd = 0
    $rsa.ImportSubjectPublicKeyInfo([Convert]::FromBase64String($b64), [ref]$rd)
    Log "pubKeySize=$($rsa.KeySize)"

    $pwd = '__RSA__' + [Convert]::ToBase64String($rsa.Encrypt([Text.Encoding]::UTF8.GetBytes($Pass), [System.Security.Cryptography.RSAEncryptionPadding]::Pkcs1))

    $detRaw = curl.exe -s -b $cj -c $cj -A $UA -X POST `
        -H 'Content-Type: application/x-www-form-urlencoded' `
        --data "username=$([uri]::EscapeDataString($User))&password=$([uri]::EscapeDataString($pwd))&fpVisitorId=" `
        "$CAS/cas/mfa/detect"
    $det = $detRaw | ConvertFrom-Json
    if ($det.code -ne 0) { throw "mfa/detect 失败: $detRaw" }
    $state = $det.data.state
    Log "mfa need=$($det.data.need) state=$state"

    $body = "username=$([uri]::EscapeDataString($User))&password=$([uri]::EscapeDataString($pwd))" +
            "&captcha=&mfaState=$state&currentMenu=1&failN=-1&execution=$exec" +
            "&_eventId=submit&geolocation=&fpVisitorId="
    $r2 = (curl.exe -s -i -b $cj -c $cj -A $UA -X POST `
        -H 'Content-Type: application/x-www-form-urlencoded' --data $body "$loginUrl") -join "`n"
    $loc = ([regex]::Match($r2, '(?im)^location:\s*(.+)$')).Groups[1].Value.Trim()
    if ($loc -notmatch 'ticket=') {
        $need = $det.data.need
        if ($need) { throw "该账号需要二次验证(MFA)，Web 登录路径可达，命令行路径不可" }
        throw "登录未返回 ticket（检查账号密码/风控）"
    }
    $ticket = [uri]::UnescapeDataString(([regex]::Match($loc, 'ticket=([^&\s]+)')).Groups[1].Value)
    Log "ticket.len=$($ticket.Length)"

    $payload = Dec-B64Url ($ticket.Split('.')[1])
    $obj = $payload | ConvertFrom-Json
    Log ("sub=" + $obj.sub + " identityType=" + $obj.identityTypeCode)
    return $obj.idToken
}
finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
