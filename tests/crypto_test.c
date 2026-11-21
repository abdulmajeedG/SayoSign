#include "sayo.h"
#include <openssl/evp.h>
#include <stdio.h>
#include <string.h>
static void hex(const char *l, const uint8_t *p, size_t n){printf("%s=",l);for(size_t i=0;i<n;i++)printf("%02x",p[i]);printf("\n");}
int main(){
 uint8_t a[32];for(int i=0;i<32;i++)a[i]=(uint8_t)(i*7+3);
 sayo_srp s;sayo_srp_init(&s,a);hex("A",s.A,256);
 uint8_t B[256];for(int i=0;i<256;i++)B[i]=(uint8_t)(255-i);B[0]=0x55;
 uint8_t salt[16];for(int i=0;i<16;i++)salt[i]=(uint8_t)(i+1);
 uint8_t pk[32];sayo_pbkdf2_sha256((const uint8_t*)"pass",4,salt,16,1000,pk,32);hex("PK",pk,32);
 sayo_srp_process(&s,"user@x.com",pk,32,salt,16,B,256);hex("K",s.K,32);hex("M1",s.M1,32);hex("M2",s.M2,32);
 uint8_t h[32];sayo_hmac_sha256((const uint8_t*)"key",3,(const uint8_t*)"msg",3,h);hex("HMAC",h,32);
 uint8_t key[32],iv[16];for(int i=0;i<32;i++)key[i]=(uint8_t)i;for(int i=0;i<16;i++)iv[i]=(uint8_t)(100+i);
 const char *msg="hello sayosign, this is a test of cbc and gcm modes!!";size_t ml=strlen(msg);
 sayo_buf enc,dec;sayo_aes_cbc_encrypt(key,32,iv,(const uint8_t*)msg,ml,&enc);
 unsigned char o[256];int ol=0,ol2=0;EVP_CIPHER_CTX *c=EVP_CIPHER_CTX_new();EVP_DecryptInit_ex(c,EVP_aes_256_cbc(),NULL,key,iv);EVP_DecryptUpdate(c,o,&ol,enc.data,(int)enc.len);EVP_DecryptFinal_ex(c,o+ol,&ol2);printf("CBC openssl-dec ok=%d\n",ol+ol2==(int)ml&&!memcmp(o,msg,ml));
 sayo_aes_cbc_decrypt(key,32,iv,enc.data,enc.len,&dec);printf("CBC self-dec ok=%d\n",dec.len==ml&&!memcmp(dec.data,msg,ml));
 for(int ivl=12;ivl<=16;ivl+=4){unsigned char ct[256],tag[16];int cl=0,t2=0;EVP_CIPHER_CTX *g=EVP_CIPHER_CTX_new();EVP_EncryptInit_ex(g,EVP_aes_256_gcm(),NULL,NULL,NULL);EVP_CIPHER_CTX_ctrl(g,EVP_CTRL_GCM_SET_IVLEN,ivl,NULL);EVP_EncryptInit_ex(g,NULL,NULL,key,iv);EVP_EncryptUpdate(g,NULL,&cl,(const unsigned char*)"XYZ",3);EVP_EncryptUpdate(g,ct,&cl,(const unsigned char*)msg,(int)ml);EVP_EncryptFinal_ex(g,ct+cl,&t2);EVP_CIPHER_CTX_ctrl(g,EVP_CTRL_GCM_GET_TAG,16,tag);
 sayo_buf gd;int rc=sayo_aes_gcm_decrypt(key,32,iv,(size_t)ivl,(const uint8_t*)"XYZ",3,ct,ml,tag,&gd);printf("GCM iv%d ok=%d\n",ivl,rc==0&&gd.len==ml&&!memcmp(gd.data,msg,ml));}
 return 0;}
