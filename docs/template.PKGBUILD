# Maintainer: Name <email@example.com>

pkgname=example
pkgver=1.0.0
pkgrel=1
pkgdesc='Concise package description without repeating the package name'
arch=('x86_64')
url='https://github.com/owner/upstream-project'
license=('SPDX-Identifier')
# Set these to the names used by the upstream source archive.
_srcname=upstream-project
_license_file=LICENSE
depends=()
makedepends=()
checkdepends=()
optdepends=()
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('REPLACE_WITH_SHA256')

prepare() {
  cd "$_srcname-$pkgver"
  # Apply auditable patches here with patch(1).
}

build() {
  cd "$_srcname-$pkgver"
  ./configure --prefix=/usr
  make
}

check() {
  cd "$_srcname-$pkgver"
  make check
}

package() {
  cd "$_srcname-$pkgver"
  make DESTDIR="$pkgdir" install
  install -Dm644 "$_license_file" "$pkgdir/usr/share/licenses/$pkgname/${_license_file##*/}"
}
