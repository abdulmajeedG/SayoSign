#ifndef SAYO_H
#define SAYO_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint8_t *data;
    size_t len;
    size_t cap;
} sayo_buf;

void sayo_buf_init(sayo_buf *b);
void sayo_buf_free(sayo_buf *b);
int sayo_buf_reserve(sayo_buf *b, size_t extra);
int sayo_buf_append(sayo_buf *b, const void *p, size_t n);
int sayo_buf_byte(sayo_buf *b, uint8_t v);
int sayo_buf_be32(sayo_buf *b, uint32_t v);
int sayo_buf_be64(sayo_buf *b, uint64_t v);
int sayo_buf_str(sayo_buf *b, const char *s);
int sayo_buf_fill(sayo_buf *b, uint8_t v, size_t n);
int sayo_read_file(const char *path, sayo_buf *out);
int sayo_write_file(const char *path, const void *p, size_t n);

void sayo_sha1(const void *p, size_t n, uint8_t out[20]);
void sayo_sha256(const void *p, size_t n, uint8_t out[32]);

typedef int (*sayo_rsa_sign_fn)(void *ctx, const uint8_t *msg, size_t msg_len, sayo_buf *sig);

typedef struct {
    const uint8_t *cert_der;
    size_t cert_len;
    const uint8_t **chain_der;
    const size_t *chain_len;
    size_t chain_count;
    sayo_rsa_sign_fn sign;
    void *sign_ctx;
} sayo_identity;

typedef struct {
    const char *bundle_id;
    const char *display_name;
    const char *version;
    const char *short_version;
    const char *icon_png_path;
    const char *entitlements_xml_path;
    const char **inject_paths;
    size_t inject_count;
    const char *hook_framework_path;
    int remove_plugins;
    int remove_watch;
    int remove_url_schemes;
    int file_sharing;
    int min_ios_override;
    const char *min_ios;
    int compression_level;
} sayo_sign_options;

typedef void (*sayo_progress_fn)(void *ctx, double fraction, const char *stage);

int sayo_unzip(const char *zip_path, const char *dest_dir, sayo_progress_fn progress, void *ctx);
int sayo_zip_dir(const char *src_dir, const char *zip_path, int level, sayo_progress_fn progress, void *ctx);

int sayo_sign_app(const char *app_dir,
                  const uint8_t *provision, size_t provision_len,
                  const sayo_identity *identity,
                  const sayo_sign_options *opts,
                  sayo_progress_fn progress, void *ctx);

int sayo_sign_ipa(const char *ipa_in, const char *ipa_out, const char *work_dir,
                  const uint8_t *provision, size_t provision_len,
                  const sayo_identity *identity,
                  const sayo_sign_options *opts,
                  sayo_progress_fn progress, void *ctx);

int sayo_extract_deb(const char *deb_path, const char *dest_dir);
int sayo_collect_tweak_dylibs(const char *root, char ***out_paths, size_t *out_count);
void sayo_free_paths(char **paths, size_t count);

int sayo_provision_entitlements_xml(const uint8_t *provision, size_t len, sayo_buf *xml);
int sayo_provision_plist_xml(const uint8_t *provision, size_t len, sayo_buf *xml);

int sayo_ocsp_request(const uint8_t *cert_der, size_t cert_len,
                      const uint8_t *issuer_der, size_t issuer_len,
                      sayo_buf *req, char *url, size_t url_cap);
int sayo_ocsp_parse(const uint8_t *resp, size_t len, int *status, int64_t *revoked_at);

int sayo_csr_info(const uint8_t *pubkey_pkcs1, size_t pub_len, const char *cn, sayo_buf *tbs);
int sayo_csr_finish(const uint8_t *tbs, size_t tbs_len, const uint8_t *sig, size_t sig_len, sayo_buf *csr);

typedef struct {
    char subject_cn[256];
    char subject_ou[128];
    char subject_o[256];
    char issuer_cn[256];
    char issuer_ou[128];
    char serial_hex[80];
    int64_t not_before;
    int64_t not_after;
} sayo_cert_info;

int sayo_cert_parse(const uint8_t *der, size_t len, sayo_cert_info *ci);
int sayo_cert_issued_by(const uint8_t *cert, size_t cl, const uint8_t *issuer, size_t il);
size_t sayo_apple_chain(const uint8_t *leaf, size_t leaf_len, const uint8_t **out, size_t *out_len, size_t cap);
int sayo_macho_inject(const char *binary, const char *load_path, int weak);
int sayo_zstd_decode(const uint8_t *p, size_t n, sayo_buf *out);

const char *sayo_last_error(void);
void sayo_set_error(const char *fmt, ...);

#ifdef __cplusplus
}
#endif

#endif
