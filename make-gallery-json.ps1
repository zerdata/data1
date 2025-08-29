param(
  # Thư mục Gallery (chứa các album là thư mục con)
  [string]$GalleryRoot = "C:\repo\data1\Gallery",

  # true -> tạo index.json trong từng album
  # false -> tạo <Album>.json ở ngay dưới $GalleryRoot
  [bool]$PerAlbumIndex = $true,

  # Có xuất albums.json hay không
  [bool]$WriteAlbumsJson = $true
)

# ---- cấu hình bộ lọc file ảnh ----
$validExt = @(".jpg",".jpeg",".png",".webp",".gif",".avif",".pic256",".pic256.jpg")

function Is-ImageFile([string]$name) {
  $n = $name.ToLower()
  foreach($e in $validExt){
    if ($n.EndsWith($e)) { return $true }
  }
  return $false
}

# Sắp xếp "thông minh" theo số trong tên nếu có (001, 12, 1000178...), nếu không có thì theo tên
function Sort-Key([string]$name) {
  $m = [regex]::Match($name, '\d+')
  if ($m.Success) { return [int64]$m.Value }
  return [Int64]::MaxValue  # đẩy không-số xuống cuối, rồi sort tiếp theo tên
}

# Tạo mảng object cho 1 album
function Build-Album-List([string]$albumPath) {
  $files = Get-ChildItem -LiteralPath $albumPath -File -ErrorAction SilentlyContinue |
           Where-Object { Is-ImageFile $_.Name } |
           Sort-Object @{ Expression = { Sort-Key $_.Name } }, @{ Expression = { $_.Name } }

  return ,$files  # luôn trả về mảng (kể cả rỗng)
}

# Ghi JSON UTF-8 (không BOM)
function Write-Json([Parameter(Mandatory=$true)][object]$obj, [Parameter(Mandatory=$true)][string]$outPath) {
  $json = $obj | ConvertTo-Json -Depth 3
  $dir = Split-Path -Parent $outPath
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  Set-Content -LiteralPath $outPath -Value $json -Encoding utf8
  Write-Host "  -> $outPath"
}

# ---- chạy ----
if (-not (Test-Path -LiteralPath $GalleryRoot)) {
  Write-Error "Không tìm thấy thư mục: $GalleryRoot"
  exit 1
}

Write-Host "Scan albums in: $GalleryRoot" -ForegroundColor Cyan

$albumDirs = Get-ChildItem -LiteralPath $GalleryRoot -Directory -ErrorAction SilentlyContinue
$albumNames = @()

foreach ($dir in $albumDirs) {
  $album = $dir.Name
  $albumPath = Join-Path $GalleryRoot $album
  Write-Host "• Album: $album"

  $list = Build-Album-List $albumPath
  if ($list.Count -eq 0) {
    Write-Host "  (bỏ qua: không có file ảnh phù hợp)" -ForegroundColor Yellow
    continue
  }

  $albumNames += $album

  if ($PerAlbumIndex) {
    # index.json trong thư mục album: [{src,title}]
    $items = @()
    foreach ($f in $list) {
      $title = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
      $items += [pscustomobject]@{ src = $f.Name; title = $title }
    }
    $outPath = Join-Path $albumPath "index.json"
    Write-Json $items $outPath
  }
  else {
    # <Album>.json ngay dưới Gallery: ["filename.ext", ...] (hoặc object nếu bạn thích)
    $items = $list | ForEach-Object { $_.Name }
    $outPath = Join-Path $GalleryRoot ("{0}.json" -f $album)
    Write-Json $items $outPath
  }
}

if ($WriteAlbumsJson) {
  $albumsJsonPath = Join-Path $GalleryRoot "albums.json"
  Write-Json $albumNames $albumsJsonPath
}

Write-Host "Done." -ForegroundColor Green