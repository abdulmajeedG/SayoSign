#include "sayo.h"
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/pkcs12.h>
#include <openssl/provider.h>
#include <openssl/x509.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

static int ossl_sign(void *ctx, const uint8_t *msg, size_t n, sayo_buf *sig) {
    EVP_PKEY *key = ctx;
    EVP_MD_CTX *m = EVP_MD_CTX_new();
    size_t sl = 0;
    int ok = EVP_DigestSignInit(m, NULL, EVP_sha256(), NULL, key) == 1 &&
             EVP_DigestSign(m, NULL, &sl, msg, n) == 1;
    if (ok) {
        sayo_buf_init(sig);
        sayo_buf_reserve(sig, sl);
        ok = EVP_DigestSign(m, sig->data, &sl, msg, n) == 1;
        sig->len = sl;
    }
    EVP_MD_CTX_free(m);
    return ok ? 0 : -1;
}

static void progress(void *ctx, double f, const char *stage) {
    (void)ctx;
    fprintf(stderr, "\r[%3d%%] %-10s", (int)(f * 100), stage);
    fflush(stderr);
}

static void usage(void) {
    fprintf(stderr,
            "usage:\n"
            "  sayosign sign -k cert.p12 -p password -m profile.mobileprovision -i in.ipa -o out.ipa\n"
            "               [-b bundle.id] [-n name] [-v version] [-s short_version] [-c icon.png]\n"
            "               [-e extra.entitlements] [-l tweak.dylib|tweak.deb|X.framework]... [-H Hook.framework]\n"
            "               [-z level] [-x remove plugins] [-w remove watch] [-f file sharing]\n"
            "  sayosign info -k cert.p12 -p password\n"
            "  sayosign ocsp -k cert.p12 -p password\n"
            "  sayosign unzip in.zip outdir | zip dir out.zip | deb in.deb outdir | zstd in.zst out\n");
}

static int load_p12(const char *path, const char *pass, EVP_PKEY **key, X509 **cert) {
    OSSL_PROVIDER_load(NULL, "legacy");
    OSSL_PROVIDER_load(NULL, "default");
    FILE *f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "cannot open %s\n", path); return -1; }
    PKCS12 *p = d2i_PKCS12_fp(f, NULL);
    fclose(f);
    if (!p) { fprintf(stderr, "invalid p12\n"); return -1; }
    STACK_OF(X509) *ca = NULL;
    if (!PKCS12_parse(p, pass, key, cert, &ca)) {
        fprintf(stderr, "wrong p12 password or unsupported p12\n");
        ERR_print_errors_fp(stderr);
        PKCS12_free(p);
        return -1;
    }
    PKCS12_free(p);
    return 0;
}

static uint8_t *cert_der(X509 *c, size_t *len) {
    int n = i2d_X509(c, NULL);
    uint8_t *b = malloc((size_t)n), *q = b;
    i2d_X509(c, &q);
    *len = (size_t)n;
    return b;
}

int main(int argc, char **argv) {
    if (argc < 2) { usage(); return 1; }
    const char *cmd = argv[1];
    if (!strcmp(cmd, "unzip") && argc == 4) {
        int rc = sayo_unzip(argv[2], argv[3], progress, NULL);
        fprintf(stderr, "\n");
        if (rc) fprintf(stderr, "error: %s\n", sayo_last_error());
        return rc ? 1 : 0;
    }
    if (!strcmp(cmd, "zip") && argc == 4) {
        int rc = sayo_zip_dir(argv[2], argv[3], 6, progress, NULL);
        fprintf(stderr, "\n");
        if (rc) fprintf(stderr, "error: %s\n", sayo_last_error());
        return rc ? 1 : 0;
    }
    if (!strcmp(cmd, "deb") && argc == 4) {
        if (sayo_extract_deb(argv[2], argv[3])) { fprintf(stderr, "error: %s\n", sayo_last_error()); return 1; }
        char **paths;
        size_t n;
        sayo_collect_tweak_dylibs(argv[3], &paths, &n);
        for (size_t i = 0; i < n; i++) printf("%s\n", paths[i]);
        sayo_free_paths(paths, n);
        return 0;
    }
    if (!strcmp(cmd, "zstd") && argc == 4) {
        sayo_buf in, out;
        if (sayo_read_file(argv[2], &in)) return 1;
        sayo_buf_init(&out);
        if (sayo_zstd_decode(in.data, in.len, &out)) { fprintf(stderr, "error: %s\n", sayo_last_error()); return 1; }
        sayo_write_file(argv[3], out.data, out.len);
        return 0;
    }

    const char *p12 = NULL, *pass = "", *prov = NULL, *in = NULL, *out = NULL;
    sayo_sign_options o;
    memset(&o, 0, sizeof o);
    o.compression_level = 6;
    const char *injects[64];
    size_t ninj = 0;
    char *tmpdirs[64];
    size_t ntmp = 0;
    int opt;
    optind = 2;
    while ((opt = getopt(argc, argv, "k:p:m:i:o:b:n:v:s:c:e:l:H:z:xwf")) != -1) {
        switch (opt) {
        case 'k': p12 = optarg; break;
        case 'p': pass = optarg; break;
        case 'm': prov = optarg; break;
        case 'i': in = optarg; break;
        case 'o': out = optarg; break;
        case 'b': o.bundle_id = optarg; break;
        case 'n': o.display_name = optarg; break;
        case 'v': o.version = optarg; break;
        case 's': o.short_version = optarg; break;
        case 'c': o.icon_png_path = optarg; break;
        case 'e': o.entitlements_xml_path = optarg; break;
        case 'H': o.hook_framework_path = optarg; break;
        case 'z': o.compression_level = atoi(optarg); break;
        case 'x': o.remove_plugins = 1; break;
        case 'w': o.remove_watch = 1; break;
        case 'f': o.file_sharing = 1; break;
        case 'l': {
            size_t l = strlen(optarg);
            if (l > 4 && !strcmp(optarg + l - 4, ".deb")) {
                char *d = malloc(4096);
                snprintf(d, 4096, "/tmp/sayodeb.%d.%zu", getpid(), ntmp);
                if (sayo_extract_deb(optarg, d)) { fprintf(stderr, "error: %s\n", sayo_last_error()); return 1; }
                tmpdirs[ntmp++] = d;
                char **paths;
                size_t n;
                sayo_collect_tweak_dylibs(d, &paths, &n);
                for (size_t i = 0; i < n && ninj < 64; i++) injects[ninj++] = strdup(paths[i]);
                sayo_free_paths(paths, n);
            } else if (ninj < 64) {
                injects[ninj++] = optarg;
            }
            break;
        }
        default: usage(); return 1;
        }
    }
    o.inject_paths = injects;
    o.inject_count = ninj;
    if (!p12) { usage(); return 1; }
    EVP_PKEY *key = NULL;
    X509 *cert = NULL;
    if (load_p12(p12, pass, &key, &cert)) return 1;
    size_t cl;
    uint8_t *cd = cert_der(cert, &cl);
    sayo_cert_info ci;
    sayo_cert_parse(cd, cl, &ci);
    const uint8_t *chain[8];
    size_t chain_len[8];
    size_t nchain = sayo_apple_chain(cd, cl, chain, chain_len, 8);

    if (!strcmp(cmd, "info") || !strcmp(cmd, "ocsp")) {
        char a[64], b[64];
        time_t t1 = (time_t)ci.not_before, t2 = (time_t)ci.not_after;
        strftime(a, sizeof a, "%Y-%m-%d %H:%M", gmtime(&t1));
        strftime(b, sizeof b, "%Y-%m-%d %H:%M", gmtime(&t2));
        printf("subject: %s\nteam: %s\norg: %s\nissuer: %s (%s)\nserial: %s\nvalid: %s .. %s\nchain: %zu\n",
               ci.subject_cn, ci.subject_ou, ci.subject_o, ci.issuer_cn, ci.issuer_ou, ci.serial_hex, a, b, nchain);
        if (!strcmp(cmd, "ocsp")) {
            if (!nchain) { fprintf(stderr, "issuer not found\n"); return 1; }
            sayo_buf req;
            char url[512];
            if (sayo_ocsp_request(cd, cl, chain[0], chain_len[0], &req, url, sizeof url)) { fprintf(stderr, "%s\n", sayo_last_error()); return 1; }
            sayo_write_file("/tmp/sayo_ocsp.req", req.data, req.len);
            char cmdline[1024];
            snprintf(cmdline, sizeof cmdline, "curl -s -X POST -H 'Content-Type: application/ocsp-request' --data-binary @/tmp/sayo_ocsp.req '%s' -o /tmp/sayo_ocsp.resp", url);
            if (system(cmdline)) { fprintf(stderr, "curl failed\n"); return 1; }
            sayo_buf resp;
            if (sayo_read_file("/tmp/sayo_ocsp.resp", &resp)) return 1;
            int st;
            int64_t when;
            if (sayo_ocsp_parse(resp.data, resp.len, &st, &when)) { fprintf(stderr, "%s\n", sayo_last_error()); return 1; }
            printf("ocsp: %s (%s)\n", st == 0 ? "GOOD" : st == 1 ? "REVOKED" : "UNKNOWN", url);
            if (st == 1) {
                time_t w = (time_t)when;
                strftime(a, sizeof a, "%Y-%m-%d %H:%M", gmtime(&w));
                printf("revoked at: %s\n", a);
            }
        }
        return 0;
    }
    if (strcmp(cmd, "sign") || !prov || !in || !out) { usage(); return 1; }
    sayo_buf pb;
    if (sayo_read_file(prov, &pb)) { fprintf(stderr, "%s\n", sayo_last_error()); return 1; }
    sayo_identity id = { cd, cl, chain, chain_len, nchain, ossl_sign, key };
    char work[256];
    snprintf(work, sizeof work, "/tmp/sayosign.%d", getpid());
    int rc = sayo_sign_ipa(in, out, work, pb.data, pb.len, &id, &o, progress, NULL);
    fprintf(stderr, "\n");
    for (size_t i = 0; i < ntmp; i++) {
        char c[4200];
        snprintf(c, sizeof c, "rm -rf '%s'", tmpdirs[i]);
        if (system(c)) {}
    }
    if (rc) { fprintf(stderr, "error: %s\n", sayo_last_error()); return 1; }
    printf("signed: %s\n", out);
    return 0;
}
