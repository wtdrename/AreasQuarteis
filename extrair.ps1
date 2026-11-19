# Descarrega os dados que a página "index.html" usa e grava-os na pasta dados, como ficheiros .js
# (uma página aberta do disco carrega .js, mas não .json). Não fica nada a correr: faz os pedidos e termina.
#   - ruas de Lisboa e arredores, do OpenStreetMap (Overpass): tipo de via, sentidos únicos, velocidade máxima
#   - áreas atuais dos quartéis, do goMAP (precisa do token do goMAP)
# Corre pelo "Extrair dados.bat", ou à mão:
#   powershell -ExecutionPolicy Bypass -File extrair.ps1                      (tudo; pede o token)
#   powershell -ExecutionPolicy Bypass -File extrair.ps1 -SoRuas              (só as ruas)
#   powershell -ExecutionPolicy Bypass -File extrair.ps1 -SoAreas -Token xxx  (só as áreas)

param([switch]$SoRuas, [switch]$SoAreas, [string]$Token)

$ErrorActionPreference = 'Stop'
$Dados = Join-Path $PSScriptRoot 'dados'
New-Item -ItemType Directory -Force $Dados | Out-Null

# Lisboa com margem: os percursos podem passar pelos concelhos ao lado
$Caixa = '38.67,-9.26,38.81,-9.07'
$Overpass = @('https://overpass-api.de/api/interpreter', 'https://overpass.kumi.systems/api/interpreter')
$Tipos = 'motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|road|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link'
$Temas = 'https://gisrsb.cm-lisboa.pt/arcgisrsb/rest/services/APP_RSB/Temas_RSB_INAG_WGS84/MapServer/'
$CamadaQuarteis = 14
$GoMAP = 'https://cmlsvc.cm-lisboa.pt/'

# pedido HTTP (POST se houver corpo); devolve o texto em UTF-8. Vai pelo curl.exe do Windows: neste PC o .NET do
# PowerShell não consegue o canal seguro (TLS) com o OpenStreetMap. O corpo vai num ficheiro para as aspas da consulta
# não se perderem na passagem para o curl
function Pedir([string]$url, [string]$corpo, [string]$referer) {
    $saida = [IO.Path]::GetTempFileName(); $ficheiroCorpo = $null
    $opcoes = @('-sS', '-L', '--compressed', '--max-time', '300', '-A', 'areas-quarteis-extrair', '-o', $saida, '-w', '%{http_code}')
    if ($referer) { $opcoes += @('-e', $referer) }
    if ($corpo) {
        $ficheiroCorpo = [IO.Path]::GetTempFileName()
        [IO.File]::WriteAllText($ficheiroCorpo, $corpo, (New-Object Text.UTF8Encoding $false))
        $opcoes += @('--data-binary', "@$ficheiroCorpo", '-H', 'Content-Type: application/x-www-form-urlencoded')
    }
    try {
        $codigo = & curl.exe @opcoes $url
        if ($LASTEXITCODE -ne 0) { throw "sem ligação (curl $LASTEXITCODE)" }
        if ($codigo -ne '200') { throw "o servidor respondeu $codigo" }
        return [IO.File]::ReadAllText($saida, [Text.Encoding]::UTF8)
    } finally { Remove-Item (@($saida, $ficheiroCorpo) | Where-Object { $_ }) -ErrorAction SilentlyContinue }
}

# grava "window.NOME = <json>;" em UTF-8 sem BOM
function Gravar([string]$ficheiro, [string]$variavel, [string]$json, [string]$descricao) {
    $texto = "// $descricao`n// gerado por extrair.ps1 em $(Get-Date -Format 'yyyy-MM-dd HH:mm')`nwindow.$variavel = $json;`n"
    [IO.File]::WriteAllText((Join-Path $Dados $ficheiro), $texto, (New-Object Text.UTF8Encoding $false))
    Write-Host ("  gravado dados\{0} ({1:N1} MB)" -f $ficheiro, ($texto.Length / 1MB)) -ForegroundColor Green
}

# ---------- ruas (OpenStreetMap) ----------
if (-not $SoAreas) {
    Write-Host 'A descarregar as ruas de Lisboa do OpenStreetMap (pode demorar 1 a 3 minutos)...'
    $consulta = '[out:json][timeout:240];way[highway~"^(' + $Tipos + ')$"](' + $Caixa + ')->.v;.v out body qt;node(w.v);out skel qt;'
    $texto = $null
    foreach ($url in $Overpass) {
        try {
            $texto = Pedir $url ('data=' + [Uri]::EscapeDataString($consulta))
            if ($texto -match '"elements"') { break }
            Write-Host "  $url respondeu sem dados" -ForegroundColor Yellow
        } catch { Write-Host "  $url falhou: $($_.Exception.Message)" -ForegroundColor Yellow }
        $texto = $null
    }
    if (-not $texto) { throw 'nenhum servidor do OpenStreetMap respondeu; tenta outra vez daqui a uns minutos' }
    $vias = ([regex]::Matches($texto, '"type":\s*"way"')).Count
    $nos = ([regex]::Matches($texto, '"type":\s*"node"')).Count
    Write-Host "  $vias vias, $nos pontos"
    Gravar 'ruas.js' 'RUAS_OSM' $texto "ruas de Lisboa (OpenStreetMap, © colaboradores do OSM, ODbL), caixa $Caixa"
}

# ---------- áreas atuais dos quartéis (goMAP) ----------
if (-not $SoRuas) {
    if (-not $Token) {
        Write-Host ''
        Write-Host 'Para as áreas atuais é preciso o token do goMAP:' -ForegroundColor Cyan
        Write-Host '  1. abre o goMAP no Firefox e carrega F12 -> separador "Rede"'
        Write-Host '  2. mexe no mapa e escreve token= no filtro'
        Write-Host '  3. clica num pedido a gisrsb.cm-lisboa.pt e copia o endereço (ou só o que vem depois de token=)'
        Write-Host '  (mais simples: na página Areas Quarteis, botão "Atualizar áreas do goMAP", com o script Quartéis 112)'
        $Token = Read-Host 'Cola aqui o token (Enter para manter as áreas que já estão guardadas)'
    }
    # aceita o endereço inteiro ou só o token
    $Token = ($Token.Trim() -replace '^.*[?&]token=', '' -replace '&.*$', '')
    $Token = [Uri]::UnescapeDataString($Token)
}
if (-not $SoRuas -and -not $Token) {
    $guardadas = Join-Path $Dados 'areas-atuais.js'
    if (Test-Path $guardadas) { Write-Host "Áreas atuais: ficam as que já estão guardadas ($((Get-Item $guardadas).LastWriteTime.ToString('yyyy-MM-dd HH:mm')))." -ForegroundColor Green }
    else { Write-Host 'Áreas atuais: sem token, não descarreguei nenhuma.' -ForegroundColor Yellow }
} elseif (-not $SoRuas) {
    Write-Host 'A descarregar as áreas atuais dos quartéis do goMAP...'
    $corpo = 'f=json&where=1%3D1&outFields=*&returnGeometry=true&outSR=4326&token=' + [Uri]::EscapeDataString($Token)
    $texto = Pedir ($Temas + "$CamadaQuarteis/query") $corpo $GoMAP
    if ($texto -match '^\s*\{\s*"error"') {
        $erro = ($texto | ConvertFrom-Json).error
        if ($erro.code -eq 498 -or $erro.code -eq 499) { throw 'token em falta ou expirado: abre o goMAP, copia um token novo e corre outra vez' }
        throw "o goMAP recusou: $($erro.message) ($($erro.code))"
    }
    $areas = ([regex]::Matches($texto, '"rings"')).Count
    if (-not $areas) { throw 'o goMAP não devolveu nenhuma área' }
    Write-Host "  $areas áreas"
    $texto = $texto + ";`nwindow.AREAS_ATUAIS_DATA = `"$(Get-Date -Format 'yyyy-MM-dd HH:mm')`""
    Gravar 'areas-atuais.js' 'AREAS_ATUAIS' $texto "áreas atuais dos quartéis (goMAP, Temas RSB, camada $CamadaQuarteis): dados internos da CML, não publicar"
}

Write-Host ''
Write-Host 'Pronto. Abre (ou atualiza com F5) o "index.html".' -ForegroundColor Green
