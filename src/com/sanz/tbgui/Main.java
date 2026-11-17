package com.sanz.tbgui;

/*
 * TitanBG — helper UI (bukan bagian daemon).
 *
 * Tugasnya cuma dua:
 *   catalog        daftar paket + label + penanda system/user
 *   icons <pkg..>  ikon aplikasi sebagai WEBP base64, satu baris per paket
 *
 * Dijalankan lewat app_process sebagai root, bukan service, bukan daemon.
 * Semua akses framework lewat refleksi supaya tidak butuh compile SDK penuh
 * dan tetap jalan dari API 21 sampai sekarang.
 *
 * by eLSanz
 */

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.util.Base64;

import java.io.ByteArrayOutputStream;
import java.util.List;

public final class Main {

    private static final int ICON_PX = 96;

    public static void main(String[] args) {
        try {
            PackageManager pm = obtainPackageManager();
            if (pm == null) {
                System.err.println("nopm");
                System.exit(3);
            }
            String cmd = (args != null && args.length > 0) ? args[0] : "catalog";
            if ("catalog".equals(cmd)) {
                catalog(pm);
            } else if ("icons".equals(cmd)) {
                icons(pm, args);
            } else if ("probe".equals(cmd)) {
                System.out.println("probe=ok");
            } else {
                System.err.println("unknown:" + cmd);
                System.exit(2);
            }
            System.out.flush();
            System.exit(0);
        } catch (Throwable t) {
            System.err.println("fail:" + t);
            System.exit(4);
        }
    }

    /* ---------------- package manager ---------------- */

    private static PackageManager obtainPackageManager() {
        // jalur 1: ActivityThread.systemMain() -> getSystemContext()
        try {
            Class<?> at = Class.forName("android.app.ActivityThread");
            Object thread = null;
            try {
                thread = at.getMethod("currentActivityThread").invoke(null);
            } catch (Throwable ignored) {
            }
            if (thread == null) {
                try {
                    Class<?> looper = Class.forName("android.os.Looper");
                    looper.getMethod("prepareMainLooper").invoke(null);
                } catch (Throwable ignored) {
                }
                java.lang.reflect.Method m = at.getDeclaredMethod("systemMain");
                m.setAccessible(true);
                thread = m.invoke(null);
            }
            if (thread != null) {
                java.lang.reflect.Method g = at.getDeclaredMethod("getSystemContext");
                g.setAccessible(true);
                Context c = (Context) g.invoke(thread);
                if (c != null) {
                    PackageManager pm = c.getPackageManager();
                    if (pm != null) return pm;
                }
            }
        } catch (Throwable ignored) {
        }
        // jalur 2: AppGlobals.getInitialApplication()
        try {
            Class<?> ag = Class.forName("android.app.AppGlobals");
            Object app = ag.getMethod("getInitialApplication").invoke(null);
            if (app instanceof Context) {
                PackageManager pm = ((Context) app).getPackageManager();
                if (pm != null) return pm;
            }
        } catch (Throwable ignored) {
        }
        return null;
    }

    /* ---------------- catalog ---------------- */

    private static void catalog(PackageManager pm) {
        List<ApplicationInfo> list = pm.getInstalledApplications(0);
        StringBuilder sb = new StringBuilder(64 * 1024);
        for (ApplicationInfo ai : list) {
            if (ai == null || ai.packageName == null) continue;
            String label = null;
            try {
                CharSequence cs = pm.getApplicationLabel(ai);
                if (cs != null) label = cs.toString();
            } catch (Throwable ignored) {
            }
            if (label == null || label.trim().length() == 0) label = ai.packageName;
            boolean sys = (ai.flags & (ApplicationInfo.FLAG_SYSTEM | ApplicationInfo.FLAG_UPDATED_SYSTEM_APP)) != 0;
            sb.append(ai.packageName).append('\t').append(clean(label)).append('\t')
              .append(sys ? 's' : 'u').append('\n');
        }
        System.out.print(sb.toString());
    }

    /* ---------------- icons ---------------- */

    private static void icons(PackageManager pm, String[] args) {
        StringBuilder sb = new StringBuilder(64 * 1024);
        for (int i = 1; i < args.length; i++) {
            String pkg = args[i];
            if (pkg == null || pkg.length() == 0) continue;
            String b64 = "";
            try {
                ApplicationInfo ai = pm.getApplicationInfo(pkg, 0);
                Drawable d = pm.getApplicationIcon(ai);
                Bitmap bmp = render(d);
                if (bmp != null) {
                    ByteArrayOutputStream bo = new ByteArrayOutputStream(8192);
                    bmp.compress(Bitmap.CompressFormat.WEBP, 80, bo);
                    bmp.recycle();
                    b64 = Base64.encodeToString(bo.toByteArray(), Base64.NO_WRAP);
                    bo.close();
                }
            } catch (Throwable ignored) {
            }
            sb.append(pkg).append('\t').append(b64).append('\n');
        }
        System.out.print(sb.toString());
    }

    private static Bitmap render(Drawable d) {
        if (d == null) return null;
        Bitmap bmp = Bitmap.createBitmap(ICON_PX, ICON_PX, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(bmp);
        try {
            d.setBounds(0, 0, ICON_PX, ICON_PX);
            d.draw(c);
        } catch (Throwable t) {
            bmp.recycle();
            return null;
        }
        return bmp;
    }

    private static String clean(String s) {
        StringBuilder out = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char ch = s.charAt(i);
            out.append((ch == '\t' || ch == '\n' || ch == '\r') ? ' ' : ch);
        }
        String r = out.toString().trim();
        if (r.length() > 64) r = r.substring(0, 64);
        return r;
    }
}