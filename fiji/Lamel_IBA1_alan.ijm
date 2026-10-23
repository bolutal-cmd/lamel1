// Lamel ROI'leriyle IBA1 pozitif alan yuzdesi (Fiji makrosu), surum 1
//
// Calistirma: Fiji > Plugins > Macros > Run... ve bu dosyayi secin.
//
// Lamel'in "Fiji'ye aktar" bolumunden kaydedilen *_Lamel_ROI*.txt dosyalarini
// okur. Her goruntuyu Bio-Formats ile acar ve iki adimda da ayni on islemeyi
// uygular:
//   IBA1 kanali -> Z projeksiyonu -> Subtract Background (rolling ball)
//
// 1. Esik belirle
//    Rastgele secilen ornek goruntuler kod adiyla (Ornek_01, Ornek_02 ...)
//    acilir. Her birinde Threshold penceresiyle alt siniri ayarlayip OK'e
//    basarsiniz. Makro sectiginiz degerleri, ortalamasini ve ornek-goruntu
//    eslesmesini Log penceresine yazar.
//
// 2. Analiz et
//    Tek bir sabit esikle butun ROI'leri olcer ve sonuc klasorune yazar:
//      Lamel_IBA1_sonuclar.csv  her ROI icin bir satir
//      parametreler.txt         kullanilan ayarlar, atlanan goruntuler
//      kontrol/*.png            esigi gecen pikseller kirmizi, ROI sari
//      roi/*_RoiSet.zip         ROI'ler (ROI Manager ile acilir)
//
// Kanal, projeksiyon ve rolling ball ayarlari iki adimda ayni olmalidir.
// Lamel ROI koordinatlari piksel cinsindendir; goruntu Lamel'de acildigi
// boyutla Fiji'de acildigi boyut ayni degilse goruntu atlanir.

requires("1.53t");
setOption("ExpandableArrays", true);

var SEP = File.separator;
var PROJ_LABEL = newArray("Maksimum", "Ortalama", "Toplam");
var PROJ_CMD = newArray("Max Intensity", "Average Intensity", "Sum Slices");

var nRows = 0;
var rFile = newArray(0);
var rSer = newArray(0);
var rSName = newArray(0);
var rW = newArray(0);
var rH = newArray(0);
var rName = newArray(0);
var rX = newArray(0);
var rY = newArray(0);
var rTs = newArray(0);
var rSrc = newArray(0);
var rImg = newArray(0);

var nImg = 0;
var iKey = newArray(0);
var iRow = newArray(0);
var iTs = newArray(0);

var gErr = "";
var bfReady = false;
var imgDir = "";
var roiDir = "";
var outDir = "";
var headless = false;
var modeIdx = 0;
var ch = 2;
var projIdx = 0;
var radius = 50;
var thr = 0;
var nSample = 6;

// ---------- ayarlar ----------
arg = getArgument();
if (arg != "") {
	// Ornek: goruntu=/yol/;roi=/yol/;sonuc=/yol/;islem=analiz;kanal=2;proj=0;yaricap=50;esik=300;ornek=6
	headless = true;
	List.setList(replace(arg, ";", "\n"));
	imgDir = List.get("goruntu");
	roiDir = List.get("roi");
	outDir = List.get("sonuc");
	modeIdx = 1;
	if (List.get("islem") == "esik") modeIdx = 0;
	ch = parseInt(List.get("kanal"));
	projIdx = parseInt(List.get("proj"));
	radius = parseFloat(List.get("yaricap"));
	thr = parseFloat(List.get("esik"));
	nSample = parseInt(List.get("ornek"));
	List.clear();
} else {
	MODES = newArray("1. Esik belirle (kor ornekler)", "2. Analiz et (sabit esik)");
	m0 = parseInt(pget("mode", "0"));
	if (isNaN(m0) || m0 < 0 || m0 > 1) m0 = 0;
	p0 = parseInt(pget("proj", "0"));
	if (isNaN(p0) || p0 < 0 || p0 > 2) p0 = 0;
	Dialog.create("Lamel IBA1 alan yuzdesi");
	Dialog.addDirectory("Goruntu klasoru", pget("imgDir", ""));
	Dialog.addDirectory("ROI dosyalari klasoru", pget("roiDir", ""));
	Dialog.addMessage("ROI klasoru bos kalirsa goruntu klasoru kullanilir.");
	Dialog.addChoice("Islem", MODES, MODES[m0]);
	Dialog.addNumber("IBA1 kanal numarasi", pnum("ch", 2));
	Dialog.addChoice("Z projeksiyonu", PROJ_LABEL, PROJ_LABEL[p0]);
	Dialog.addNumber("Rolling ball yaricapi (piksel, 0 = yok)", pnum("radius", 50));
	Dialog.addMessage("Yalniz esik belirlemede:");
	Dialog.addNumber("Ornek goruntu sayisi", pnum("nSample", 6));
	Dialog.addMessage("Yalniz analizde:");
	Dialog.addNumber("Sabit esik (alt sinir)", pnum("thr", 0));
	Dialog.addDirectory("Sonuc klasoru", pget("outDir", ""));
	Dialog.show();
	imgDir = Dialog.getString();
	roiDir = Dialog.getString();
	outDir = Dialog.getString();
	mc = Dialog.getChoice();
	modeIdx = 0;
	if (mc == MODES[1]) modeIdx = 1;
	pc = Dialog.getChoice();
	projIdx = 0;
	for (i = 0; i < 3; i++) if (pc == PROJ_LABEL[i]) projIdx = i;
	ch = Dialog.getNumber();
	radius = Dialog.getNumber();
	nSample = Dialog.getNumber();
	thr = Dialog.getNumber();
	pset("imgDir", imgDir); pset("roiDir", roiDir); pset("outDir", outDir);
	pset("mode", modeIdx); pset("proj", projIdx); pset("ch", ch);
	pset("radius", radius); pset("nSample", nSample); pset("thr", thr);
}

imgDir = slash(imgDir);
roiDir = slash(roiDir);
outDir = slash(outDir);
if (roiDir == "") roiDir = imgDir;
if (imgDir == "" || !File.isDirectory(imgDir)) exit("Goruntu klasoru bulunamadi:\n" + imgDir);
if (!File.isDirectory(roiDir)) exit("ROI klasoru bulunamadi:\n" + roiDir);
if (isNaN(ch) || ch < 1) exit("IBA1 kanal numarasi 1 ya da daha buyuk olmali.");
ch = round(ch);
if (isNaN(radius) || radius < 0) radius = 0;
if (modeIdx == 1) {
	if (outDir == "" || !File.isDirectory(outDir)) exit("Analiz icin bir sonuc klasoru secin.");
	if (isNaN(thr) || thr <= 0) exit("Sabit esik girin. Esigi once 1. adimla (Esik belirle) belirleyin.");
}

print("\\Clear");
nFiles = readRoiFiles(roiDir);
if (nRows == 0) exit("ROI klasorunde Lamel ROI dosyasi (*_Lamel_ROI*.txt) bulunamadi:\n" + roiDir);
groupImages();
print("Lamel ROI dosyasi: " + nFiles + ", goruntu: " + nImg + ", ROI satiri: " + nRows);

if (modeIdx == 0) thresholdStep();
else analysisStep();

// ---------- 1. esik belirleme ----------
function thresholdStep() {
	if (isNaN(nSample) || nSample < 1) nSample = 6;
	N = minOf(round(nSample), nImg);
	order = Array.getSequence(nImg);
	for (i = nImg - 1; i > 0; i--) {
		j = floor(random() * (i + 1));
		t = order[i]; order[i] = order[j]; order[j] = t;
	}
	vals = newArray(0);
	who = newArray(0);
	got = 0;
	for (s = 0; s < nImg && got < N; s++) {
		k = order[s];
		setBatchMode(true);
		id = openPrepared(k);
		if (id == 0) {
			setBatchMode(false);
			print("Atlandi: " + label(k) + " (" + gErr + ")");
			continue;
		}
		code = "Ornek_" + IJ.pad(got + 1, 2);
		rename(code);
		lw = maxOf(2, round(getWidth() / 600));
		Overlay.remove;
		for (r = 0; r < nRows; r++) {
			if (rowOf(r, k) == 0) continue;
			if (makeRoi(r) == 1) Overlay.addSelection("yellow", lw);
		}
		run("Select None");
		run("Enhance Contrast", "saturated=0.35");
		if (headless) {
			setAutoThreshold("Default dark");
		} else {
			setBatchMode(false);
			run("Threshold...");
			waitForUser("Esik belirleme: " + code + " (" + (got + 1) + "/" + N + ")",
				"Threshold penceresinde:\n" +
				"- 'Dark background' isaretli olsun.\n" +
				"- Ustteki kaydiriciyla (alt sinir) IBA1 sinyalini secin.\n" +
				"- 'Apply' dugmesine basmayin.\n" +
				"Sari cizgi ROI sinirini gosterir.\n \nHazir olunca OK.");
			selectImage(id);
		}
		getThreshold(lo, hi);
		if (lo == -1) lo = NaN;
		vals[got] = lo;
		who[got] = code + "  " + label(k);
		got++;
		close();
		setBatchMode(false);
	}
	if (got == 0) exit("Hicbir ornek goruntu acilamadi. Log penceresine bakin.");

	ok = newArray(0); n = 0;
	for (i = 0; i < got; i++) if (!isNaN(vals[i])) { ok[n] = vals[i]; n++; }
	rep = "\nEsik belirleme sonucu\n";
	rep = rep + "Kanal " + ch + ", " + PROJ_LABEL[projIdx] + " Z projeksiyonu, rolling ball " + radiusText() + "\n\n";
	for (i = 0; i < got; i++) rep = rep + who[i] + "\t esik = " + num(vals[i]) + "\n";
	if (n > 0) {
		Array.getStatistics(ok, mn, mx, mean, sd);
		srt = Array.copy(ok); Array.sort(srt);
		med = srt[floor(n / 2)];
		if (n % 2 == 0) med = (srt[n / 2 - 1] + srt[n / 2]) / 2;
		rep = rep + "\nOrtalama " + d2s(mean, 1) + ", medyan " + d2s(med, 1) + ", SD " + d2s(sd, 1) +
			", en dusuk " + d2s(mn, 1) + ", en yuksek " + d2s(mx, 1) + " (n = " + n + ")\n";
		rep = rep + "Analizde bu degerlere dayanarak tek bir sabit esik kullanin.\n";
	}
	rep = rep + "Orneklerde sham ve BCAS gruplarinin ikisi de bulunmali; yoksa bu adimi yeniden calistirin.\n";
	print(rep);
	if (outDir != "" && File.isDirectory(outDir)) File.saveString(rep, outDir + "esik_belirleme_" + stamp() + ".txt");
	if (!headless) showMessage("Lamel IBA1", "Esik degerleri Log penceresinde.");
}

// ---------- 2. analiz ----------
function analysisStep() {
	setBatchMode(true);
	qcDir = outDir + "kontrol" + SEP;
	rsDir = outDir + "roi" + SEP;
	File.makeDirectory(qcDir);
	File.makeDirectory(rsDir);
	csv = "dosya,seri_no,seri_adi,roi,roi_alani,iba1_pozitif_alan,iba1_alan_yuzdesi,ortalama_yogunluk,alan_birimi,esik,kanal,projeksiyon,rolling_ball_px,piksel_boyutu,durum\n";
	skipped = "";
	nDone = 0; nRoi = 0;
	for (k = 0; k < nImg; k++) {
		showProgress(k, nImg);
		showStatus("Lamel IBA1: " + (k + 1) + "/" + nImg);
		r0 = iRow[k];
		head = "" + q(rFile[r0]) + "," + rSer[r0] + "," + q(rSName[r0]) + ",";
		id = openPrepared(k);
		if (id == 0) {
			print("Atlandi: " + label(k) + " (" + gErr + ")");
			skipped = skipped + label(k) + ": " + gErr + "\n";
			csv = csv + head + ",,,,,," + thr + "," + ch + "," + PROJ_LABEL[projIdx] + "," + radius + ",," + q(gErr) + "\n";
			continue;
		}
		getPixelSize(unit, pw, ph);
		au = unit + "^2";
		if (startsWith(unit, "pixel")) au = "piksel^2";
		upper = topValue();
		base = outBase(k);
		roiManager("reset");
		for (r = 0; r < nRows; r++) {
			if (rowOf(r, k) == 0) continue;
			selectImage(id);
			if (makeRoi(r) == 0) {
				csv = csv + head + q(rName[r]) + ",,,,,," + thr + "," + ch + "," + PROJ_LABEL[projIdx] + "," + radius + "," + pw + ",ROI okunamadi\n";
				continue;
			}
			Roi.setName(rName[r]);
			roiManager("add");
			setThreshold(thr, upper);
			List.setMeasurements;
			a = List.getValue("Area");
			fr = List.getValue("%Area");
			mean = List.getValue("Mean");
			resetThreshold();
			csv = csv + head + q(rName[r]) + "," + num(a) + "," + num(a * fr / 100) + "," + num(fr) + "," + num(mean) + "," +
				q(au) + "," + thr + "," + ch + "," + PROJ_LABEL[projIdx] + "," + radius + "," + num(pw) + ",tamam\n";
			nRoi++;
		}
		if (roiManager("count") > 0) roiManager("save", rsDir + base + "_RoiSet.zip");
		roiManager("reset");
		saveQC(k, id, upper, qcDir + base + ".png");
		close("*");
		nDone++;
	}
	showProgress(1);
	resPath = outDir + "Lamel_IBA1_sonuclar.csv";
	File.saveString(csv, resPath);

	par = "Lamel IBA1 alan yuzdesi analizi\n";
	par = par + "Tarih: " + stamp() + "\n";
	par = par + "ImageJ: " + getVersion() + "\n";
	par = par + "Goruntu klasoru: " + imgDir + "\n";
	par = par + "ROI klasoru: " + roiDir + "\n";
	par = par + "IBA1 kanali: " + ch + "\n";
	par = par + "Z projeksiyonu: " + PROJ_LABEL[projIdx] + " (tum dilimler)\n";
	par = par + "Arka plan: Subtract Background, rolling ball " + radiusText() + "\n";
	par = par + "Sabit esik (alt sinir): " + thr + "\n";
	par = par + "Olcum: ROI icinde esige esit ya da buyuk piksellerin yuzdesi (%Area)\n";
	par = par + "Islenen goruntu: " + nDone + "/" + nImg + ", olculen ROI: " + nRoi + "\n";
	if (skipped != "") par = par + "\nAtlanan goruntuler:\n" + skipped;
	File.saveString(par, outDir + "parametreler.txt");
	print(par);
	setBatchMode(false);
	if (!headless) {
		open(resPath);
		showMessage("Lamel IBA1", nRoi + " ROI olculdu. Sonuclar:\n" + resPath);
	}
}

// ---------- goruntu acma ve on isleme ----------
function openPrepared(k) {
	r = iRow[k];
	file = rFile[r];
	path = imgDir + file;
	if (!File.exists(path)) {
		if (File.exists(roiDir + file)) path = roiDir + file;
		else { gErr = "goruntu dosyasi bulunamadi"; return 0; }
	}
	bf = 0;
	if (endsWith(toLowerCase(file), ".lif")) {
		bf = findSeries(path, rSer[r], rSName[r], rW[r], rH[r]);
		if (bf < 0) { gErr = "LIF icinde ayni ad ve boyutta seri bulunamadi"; return 0; }
	}
	before = nImages;
	run("Bio-Formats Importer", "open=[" + path + "] color_mode=Default view=Hyperstack stack_order=XYCZT series_" + (bf + 1)); // BF_OPEN
	if (nImages <= before) { gErr = "goruntu acilamadi"; return 0; }
	orig = getImageID();
	getDimensions(W, H, C, Z, T);
	if (W != rW[r] || H != rH[r]) {
		close();
		gErr = "boyut farkli (Fiji " + W + "x" + H + ", Lamel " + rW[r] + "x" + rH[r] + ")";
		return 0;
	}
	if (bitDepth() == 24) { close(); gErr = "RGB goruntu, kanallar ayri degil"; return 0; }
	if (ch > C) { close(); gErr = "kanal " + ch + " yok, goruntude " + C + " kanal var"; return 0; }
	opt = "title=lamel_kanal duplicate";
	if (C > 1) opt = opt + " channels=" + ch;
	if (Z > 1 && (C > 1 || T > 1)) opt = opt + " slices=1-" + Z;
	if (T > 1) opt = opt + " frames=1";
	run("Duplicate...", opt);
	work = getImageID();
	selectImage(orig);
	close();
	selectImage(work);
	if (nSlices > 1) {
		run("Z Project...", "projection=[" + PROJ_CMD[projIdx] + "]");
		p = getImageID();
		selectImage(work);
		close();
		selectImage(p);
		work = p;
	}
	if (radius > 0) run("Subtract Background...", "rolling=" + radius);
	rename("lamel_islenmis");
	return work;
}

function findSeries(path, ser, sName, w, h) {
	if (!bfReady) { run("Bio-Formats Macro Extensions"); bfReady = true; }
	Ext.setId(path);
	Ext.getSeriesCount(n);
	leaf = sName;
	p = lastIndexOf(sName, "/");
	if (p >= 0) leaf = substring(sName, p + 1);
	exact = -1; leafHit = -1; leafCount = 0;
	for (i = 0; i < n; i++) {
		Ext.setSeries(i);
		Ext.getSizeX(sx);
		Ext.getSizeY(sy);
		Ext.getSeriesName(nm);
		if (sx != w || sy != h) continue;
		if (nm == sName && exact < 0) exact = i;
		if (nm == leaf || endsWith(nm, "/" + leaf)) {
			leafCount++;
			if (leafHit < 0) leafHit = i;
		}
	}
	if (exact < 0 && leafCount == 1) exact = leafHit;
	if (exact < 0 && ser >= 1 && ser <= n) {
		Ext.setSeries(ser - 1);
		Ext.getSizeX(sx);
		Ext.getSizeY(sy);
		if (sx == w && sy == h) exact = ser - 1;
	}
	Ext.close();
	return exact;
}

// ---------- kontrol goruntusu ----------
function saveQC(k, id, upper, path) {
	selectImage(id);
	run("Select None");
	resetThreshold();
	run("Duplicate...", "title=lamel_kontrol");
	qc = getImageID();
	run("Enhance Contrast", "saturated=0.35");
	run("RGB Color");
	selectImage(id);
	setThreshold(thr, upper);
	run("Create Selection");
	resetThreshold();
	if (selectionType() != -1) {
		roiManager("add");
		selectImage(qc);
		roiManager("select", 0);
		Overlay.addSelection("", 0, "#90FF2020");
		run("Select None");
		roiManager("reset");
	}
	selectImage(qc);
	lw = maxOf(2, round(getWidth() / 600));
	for (r = 0; r < nRows; r++) {
		if (rowOf(r, k) == 0) continue;
		if (makeRoi(r) == 1) Overlay.addSelection("yellow", lw);
	}
	run("Select None");
	run("Flatten");
	if (getWidth() > 2400) run("Size...", "width=2400 height=" + round(getHeight() * 2400 / getWidth()) + " depth=1 average interpolation=Bilinear");
	saveAs("PNG", path);
	close();
	selectImage(qc);
	close();
}

// ---------- ROI dosyalari ----------
function readRoiFiles(dir) {
	list = getFileList(dir);
	nf = 0;
	for (i = 0; i < list.length; i++) {
		nm = list[i];
		if (indexOf(nm, "_Lamel_ROI") < 0 || !endsWith(toLowerCase(nm), ".txt")) continue;
		lines = split(File.openAsString(dir + nm), "\n" + fromCharCode(13));
		ts = 0; header = false; added = 0;
		for (j = 0; j < lines.length; j++) {
			ln = lines[j];
			if (startsWith(ln, "# kaydedildi_ms")) {
				p = split(ln, "\t");
				if (p.length > 1) ts = parseFloat(p[1]);
				continue;
			}
			if (lengthOf(ln) == 0 || startsWith(ln, "#")) continue;
			if (startsWith(ln, "file\t")) { header = true; continue; }
			if (!header) continue;
			f = split(ln, "(\t)");
			if (f.length < 9) continue;
			rFile[nRows] = urlDecode(f[0]);
			rSer[nRows] = parseInt(f[1]);
			rSName[nRows] = urlDecode(f[2]);
			rW[nRows] = parseInt(f[3]);
			rH[nRows] = parseInt(f[4]);
			rName[nRows] = urlDecode(f[5]);
			rX[nRows] = f[7];
			rY[nRows] = f[8];
			rTs[nRows] = ts;
			rSrc[nRows] = nm;
			nRows++;
			added++;
		}
		if (added > 0) nf++;
		else print("Uyari: " + nm + " icinde ROI satiri yok.");
	}
	return nf;
}

// Ayni goruntu birden cok ROI dosyasinda varsa en son kaydedilen dosya kullanilir.
function groupImages() {
	for (r = 0; r < nRows; r++) {
		key = rFile[r] + "|" + rSer[r] + "|" + rSName[r];
		k = -1;
		for (j = 0; j < nImg; j++) {
			if (iKey[j] == key) { k = j; break; }
		}
		if (k < 0) {
			k = nImg;
			iKey[k] = key; iRow[k] = r; iTs[k] = rTs[r];
			nImg++;
		} else if (rTs[r] > iTs[k]) {
			iTs[k] = rTs[r]; iRow[k] = r;
		}
		rImg[r] = k;
	}
	for (r = 0; r < nRows; r++) {
		if (rTs[r] < iTs[rImg[r]]) print("Eski kayit kullanilmadi: " + rSrc[r] + ", " + label(rImg[r]) + ", " + rName[r]);
	}
}

function rowOf(r, k) {
	if (rImg[r] == k && rTs[r] == iTs[k]) return 1;
	return 0;
}

function makeRoi(r) {
	xs = split(rX[r], " ");
	ys = split(rY[r], " ");
	n = minOf(xs.length, ys.length);
	if (n < 3) return 0;
	x = newArray(n); y = newArray(n);
	for (i = 0; i < n; i++) { x[i] = parseFloat(xs[i]); y[i] = parseFloat(ys[i]); }
	makeSelection("polygon", x, y);
	return 1;
}

// ---------- yardimcilar ----------
function label(k) {
	r = iRow[k];
	if (rSName[r] == "-" || rSName[r] == "") return rFile[r];
	return rFile[r] + " / " + rSName[r];
}

function outBase(k) {
	r = iRow[k];
	b = rFile[r];
	d = lastIndexOf(b, ".");
	if (d > 0) b = substring(b, 0, d);
	if (rSName[r] != "-" && rSName[r] != "") b = b + "_" + rSName[r];
	b = replace(b, "[^A-Za-z0-9._-]+", "_");
	if (lengthOf(b) > 100) b = substring(b, 0, 100);
	return IJ.pad(k + 1, 3) + "_" + b;
}

function topValue() {
	bd = bitDepth();
	if (bd == 8) return 255;
	if (bd == 16) return 65535;
	return 1e30;
}

function radiusText() {
	if (radius > 0) return "" + radius + " piksel";
	return "yok";
}

function urlDecode(s) {
	return call("java.net.URLDecoder.decode", s, "UTF-8");
}

function q(s) {
	return "\"" + replace("" + s, "\"", "\"\"") + "\"";
}

function num(v) {
	if (isNaN(v)) return "";
	return d2s(v, 4);
}

function slash(d) {
	if (d == "") return d;
	if (!endsWith(d, "/") && !endsWith(d, "\\")) d = d + SEP;
	return d;
}

function stamp() {
	getDateAndTime(yr, mo, dw, dm, hr, mi, se, ms);
	return "" + yr + "-" + IJ.pad(mo + 1, 2) + "-" + IJ.pad(dm, 2) + "_" + IJ.pad(hr, 2) + IJ.pad(mi, 2);
}

function pget(k, d) {
	return call("ij.Prefs.get", "lamel." + k, d);
}

function pnum(k, d) {
	v = parseFloat(pget(k, "" + d));
	if (isNaN(v)) return d;
	return v;
}

function pset(k, v) {
	call("ij.Prefs.set", "lamel." + k, "" + v);
}
