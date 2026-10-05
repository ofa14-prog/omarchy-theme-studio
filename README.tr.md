# Omarchy için Theme Studio

Kendi [Omarchy](https://omarchy.org) temanı canlı bir masaüstü tuvali üzerinde
tasarla. Her rengi düzenle, palet üret, duvar kağıdı seç, sonucu gerçek
masaüstünde önizle; ardından kaydet, uygula, içe ya da dışa aktar.

[English README](README.md)

![Theme Studio](preview.png)

## Özellikler

- **Masaüstü tuvali:** Bar, terminal, editör, başlatıcı, sistem monitörü,
  bildirim ve pencere kenarlarından oluşan, yalnızca düzenlediğin paletle
  boyanan sahte bir Omarchy masaüstü. Bir öğeye tıklayınca onu boyayan renk seçilir.
- **Palet sekmesi** (`colors.toml`'daki 25 renk) ve WCAG oranlarını gösteren,
  tek tıkla *Düzelt* seçeneği olan **kontrast sekmesi**.
- **Renk seçici:** HSV kare, ton şeridi, hex alanı, aç/koyulaştır/doygunluk.
- **Palet üretici:** vurgudan tam palet (Dengeli, Pastel, Neon, Soluk, Mono),
  tonları ve parlak renkleri türetme, rastgele, koyu ⇄ açık, duvar kağıdından palet.
- **Pencere kenarı:** düz renk ya da açılı gradyan.
- Temaya özel **duvar kağıtları ve ikon teması**.
- **Canlı önizleme:** Omarchy'nin kendi şablon motoruyla paleti çalışan
  shell'e uygular; uygulamadan kapatırsan mevcut tema geri gelir.
- **Geri al / yinele**, kaydedilmemiş değişiklik uyarıları.
- **Kaydet** (`~/.config/omarchy/themes/<ad>/`), **uygula**
  (`omarchy-theme-set`), **dışa aktar** (`.tar.gz`), **içe aktar** (arşiv,
  klasör, `colors.toml`, `alacritty.toml`, git adresi).
- İngilizce ve Türkçe arayüz (`LANG`'e göre seçilir; `THEME_STUDIO_LANG` ile
  değiştirilebilir).

## Gereksinimler

- Quickshell tabanlı `omarchy-shell` ve plugin sistemi olan bir Omarchy sürümü.
- `python3` 3.9 veya üzeri (yalnızca standart kütüphane).
- İsteğe bağlı: ImageMagick, `git`, `wl-clipboard` (Omarchy ile gelir).

## Kurulum

```bash
omarchy plugin add https://github.com/ofa14-prog/omarchy-theme-studio.git --enable
```

## Açmak

```bash
omarchy-shell shell toggle io.github.ofa14-prog.theme-studio '{}'
```

Omarchy menüsüne eklemek için `~/.config/omarchy/extensions/omarchy-menu.jsonc`
dosyasına:

```jsonc
"style.theme-studio": {"icon":"󰏘","label":"Theme Studio","action":"omarchy-shell shell toggle io.github.ofa14-prog.theme-studio '{}'"},
```

Kısayol için `~/.config/hypr/bindings.lua` dosyasına (tuşun boş olduğunu
`omarchy menu keybindings --print` ile kontrol et):

```lua
o.bind("SUPER + ALT + T", "Theme Studio", "omarchy-shell shell toggle io.github.ofa14-prog.theme-studio '{}'")
```

Klavye kısayolları, güvenlik kuralları, komut satırı kullanımı ve geliştirme
notları için [İngilizce README](README.md)'ye bak.

## Lisans

[MIT](LICENSE)
