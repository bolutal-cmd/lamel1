# Lamel

Mikroskopi görüntülerini tarayıcıda açma, bölge çizme ve ölçme aracı. Leica LIF, TIFF (ImageJ hyperstack, OME-TIFF), PNG ve JPG dosyalarını açar. Görüntüler cihazdan dışarı gönderilmez; bütün hesaplar tarayıcıda yapılır.

## Dosyalar

| Dosya | Ne işe yarar |
| --- | --- |
| `index.html` | Uygulamanın kendisi |
| `manifest.webmanifest` | Uygulama olarak yükleme bilgileri (ad, simge, açabildiği dosya türleri) |
| `sw.js` | İnternet yokken de açılmasını sağlar |
| `icons/` | Uygulama simgeleri |
| `fiji/Lamel_IBA1_alan.ijm` | Aynı analizi Fiji’de doğrulamak için makro |

## GitHub Pages’te yayınlama

1. GitHub’da yeni bir depo açın ve bu klasördeki her şeyi deponun ana dizinine yükleyin.
2. Depoda **Settings › Pages** bölümüne gidin.
3. **Source** olarak *Deploy from a branch*, dal olarak `main` ve klasör olarak `/ (root)` seçip kaydedin.
4. Bir iki dakika sonra uygulama `https://KULLANICI-ADI.github.io/DEPO-ADI/` adresinde açılır.

Ücretsiz GitHub hesabında Pages yalnız herkese açık depolarda çalışır. Bu durumda kod herkese açık olur; görüntüleriniz ve çizimleriniz ise depoya hiç gitmez.

## Uygulama olarak yükleme

- **Chrome ya da Edge (bilgisayar):** Adres çubuğunun sağındaki yükle simgesine basın. Yükledikten sonra .lif ve .tif dosyalarını çift tıklayarak Lamel’de açabilirsiniz.
- **Android (Chrome):** Menü › *Uygulamayı yükle* ya da *Ana ekrana ekle*.
- **iPhone, iPad (Safari):** Paylaş › *Ana Ekrana Ekle*.

İlk açılıştan sonra uygulama internet olmadan da çalışır.

## Kaldığınız yerden devam etme

Çizdiğiniz bölgeler, noktalar, analize seçtiğiniz görüntüler ve sonuçlar bu cihazda, bu tarayıcıda kendiliğinden kaydedilir. Kayıt dosya adına ve boyutuna bağlıdır. Aynı dosyayı yeniden açtığınızda çizimler geri gelir ve LIF projelerinde en son çalıştığınız görüntü açılır. Uygulamanın açılış ekranında son çalıştığınız dosyalar listelenir.

- Chrome ve Edge’de (bilgisayar) listedeki dosyaya basınca dosya doğrudan açılır; tarayıcı bir kez izin ister.
- Diğer tarayıcılarda dosyayı yeniden seçmeniz istenir; çizimler yine kendiliğinden yüklenir.
- Tarayıcı verilerini silerseniz kayıtlar da silinir. Yedek almak ya da başka bir cihazda devam etmek için kenar paneldeki **ROI dosyası** bölümünden bölgeleri dosyaya kaydedin.

## Güncelleme

Yeni sürümde değişen dosyaları depoya yükleyin (GitHub’da **Add file › Upload files**). Aynı adlı dosyanın üstüne yazılır. GitHub birkaç dakika içinde siteyi yeniler; uygulama, internete bağlıyken bir sonraki açılışta yeni sürümü alır. Simgeleri değiştirirseniz `sw.js` içindeki `VERSION` değerini artırın.

## Analiz yöntemi

Analiz bölümü her seçili görüntüde şu adımları uygular: seçilen kanal, bütün Z dilimlerinin projeksiyonu (maksimum, ortalama ya da toplam), arka plan çıkarma (rolling ball), isteğe bağlı medyan filtresi, sabit eşik ve isteğe bağlı olarak belirli bir alandan küçük pozitif parçaların atılması. Eşiğe eşit ya da büyük pikseller pozitif sayılır; parçalar 8 komşulukla (köşeden değen pikseller aynı parça) belirlenir.

Arka plan çıkarma ve medyan filtresi ImageJ’nin Subtract Background ve Median komutlarının koduna dayanır, parça filtresi Analyze Particles ile aynı sonucu verir. `fiji/Lamel_IBA1_alan.ijm` makrosu aynı adımları Fiji’de uygular; aynı ayarlarla iki programın sonuçları birebir aynı çıkar.
