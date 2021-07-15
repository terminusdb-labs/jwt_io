/*
  BSD 2-Clause License

  Copyright (c) 2018, Can Bican
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

  * Redistributions of source code must retain the above copyright notice, this
    list of conditions and the following disclaimer.

  * Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

:- module(jwt_io, [jwt_encode/3, jwt_decode/3, jwt_decode_head/2, setup_jwks/1]).
/** <module> Json Web Tokens implementation

Generates and verifies Json Web Tokens.

The module requires libjwt to compile.

In addition to jwt_encode/3 and jwt_decode/3, the following settings are required for proper functionality:

  * =jwt_io:clock_tolerance=: (default 60) number of seconds to tolerate differences between the encoding and decoding times.
  * =jwt_io:audience=: audience identifier for tokens - tokens that don't have this audience won't be decoded.
  * =jwt_io:jti_generator=: (default 'uuid') predicate for generating unique JTIs
  * =jwt_io:blacklist_check=: (default 'jwt_io:check_blacklist_default') predicate for checking JTIs against blacklisted JTIs.
  * =jwt_io:blacklist_add=: (default 'jwt_io:add_to_blacklist_default') predicate for adding to the list of blacklisted JTIs.
  * =jwt_io:keys=: list of keys to use. It consists of a list of dicts, consisting of:
    * =kid=: key id for identifying the key to use
    * =type=: type of the key, one of HMAC, RSA or ECDSA.
    * =algorithm=: algorithm to use, one of HS256, HS384, HS512, RS256, RS384, RS512, ES256, ES384 or ES512.
    * =key=: private key to use - string for HMAC, private key file for RSA and private PEM file for ECDSA. Optional for decoding, mandatory for encoding.
    * =public_key=: public key to use - irrelevant for HMAC, public key file for RSA and public PEM file for ECDSA.

RSA keys can be generated by:

==
ssh-keygen -t rsa -b 4096 -f sample.key
openssl rsa -in sample.key -pubout -outform PEM -out sample.key.pub
==

ECDSA keys can be generated by:

==
openssl ecparam -genkey -name secp256k1 -noout -out sample-private.pem
openssl ec -in sample-private.pem -pubout -out sample-public.pem
==

@see https://jwt.io/
@see https://github.com/benmcollins/libjwt
@author Can Bican
@license BSD
*/

:- use_foreign_library(foreign(jwt_io)).

:- use_module(library(http/json)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_json)).
:- use_module(library(settings)).

:- setting(keys,            list(dict), [],   'Signing keys').
:- setting(clock_tolerance, integer,    60,   'clock tolerance in seconds').
:- setting(audience,        string,     "",   'audience of the jwt').

:- setting(blacklist_check, atom,       check_blacklist_default,  "predicate of arity 1 to check if a JTI is blacklisted").
:- setting(blacklist_add,   atom,       add_to_blacklist_default, "predicate of arity 2 to add a JTI to blacklist with expiration").
:- setting(jti_generator,   atom,       uuid,                     "predicate of arity 1 to generate a unique JTI").

%! jwt_encode(+KeyId: atom, +Claims:dict, -Token:string) is semidet
%
% Generates a JWT token.
%   * Algorithm and keys are chosen from =jwt_io:keys= setting.
%   * If =jwt_io:audience= is set, =aud= key is added to the token.
%   * =iat= key is always added to the token.
%   * =iss= key is added If it is defined in the =jwt_io:keys= setting.
%   * =kid= key is added from =jwt_io:keys= setting.
%   * =jti= key is added by making use of =jwt_io:jwt_generator= setting.
%
% @arg KeyId the key to use for signing the token
% @arg Claims contents of the key
% @arg Token resulting token
%
jwt_encode(Kid, Claims, Token) :-
  must_be(atom, Kid),
  must_be(dict, Claims),
  get_key_from_settings(Kid, Key),
  get_jti(Jti),
  claims_with_aud(Claims, ClaimsWithAud),
  claims_with_iat(ClaimsWithAud, ClaimsWithIat),
  claims_with_iss(ClaimsWithIat, Key, ClaimsWithIss),
  ClaimsNew = ClaimsWithIss.put(_{jti: Jti}),
  atom_json_dict(Data,ClaimsNew,[as(atom)]),
  jwt_encode_from_string(Data, Token, Key.key, Key.algorithm, Kid).

%! jwt_decode(+Data: atom, -Payload:dict, +Options:options) is semidet
%
% Decodes a generated JWT token.
%
%   * =jti= is checked in the blacklist defined by =jwt_id:blacklist_check= setting, and valid JWTs are added to blacklist defined by =jwt_io:blacklist_add= setting.
%   * If =exp= is present, decoding fails if the time is past =exp=.
%   * If =nbf= is present, decoding fails if the time is before =nbf=.
%   * =iat= is checked for validity.
%
% The following options are recognized:
%   * aud(+Audience)
%     Audience for the token - if the audiences don't match, decoding fails.
%   * iss(+Issuer)
%     Issuer for the token - if the issuers don't match, decoding fails.
%
% @arg Data signed JWT token
% @arg Payload contents of the token
% @arg Options options
%
jwt_decode(Data, Payload, Options) :-
  jwt_decode_head(Data, PayloadFirst),
  atom_json_dict(PayloadFirst, PayloadHeader, [as(string)]),
  atom_string(Kid, PayloadHeader.kid),
  get_key_from_settings(Kid, KeyDict),
  jwt_decode_from_string(Data, Payload, KeyDict),
  atom_json_dict(Payload, PayloadDict, [as(string)]),
  jwt_jti_valid(PayloadDict),
  jwt_exp_valid(PayloadDict),
  jwt_nbf_valid(PayloadDict),
  jwt_iss_valid(PayloadDict, Options),
  jwt_aud_valid(PayloadDict, Options),
  jwt_iat_valid(PayloadDict).

jwt_decode_head(Data, Payload) :-
  jwt_parse_head(Data, Payload).

get_jti(Jti) :-
  setting(jti_generator, Generator),
  call(Generator, Jti).

check_blacklist_default(Jti) :-
  retract(blacklisted(Jti,Exp)),
  not_before_now(Exp),
  assertz(blacklisted(Jti,Exp)).

check_blacklist_default(Jti) :-
  retract(blacklisted(Jti,Exp)),
  assertz(blacklisted(Jti,Exp)).

add_to_blacklist_default(Jti, Exp) :-
  assertz(blacklisted(Jti,Exp)).

jwt_jti_valid(Payload) :-
  setting(blacklist_check, BlacklistCheck),
  setting(blacklist_add, BlacklistAdd),
  current_prolog_flag(max_tagged_integer, MaxInt),
  (
    get_dict(jti, Payload, JtiPayload)
  ->
    not(call(BlacklistCheck, JtiPayload)),
    (
      get_dict(exp, Payload, ExpPayload)
    -> call(BlacklistAdd, JtiPayload, ExpPayload)
    ; call(BlacklistAdd, JtiPayload, MaxInt)
    )
  ; !
  ).

jwt_nbf_valid(Payload) :-
  (
    get_dict(nbf, Payload, ExpPayload)
  -> not_after_now(ExpPayload)
  ; !
  ).

jwt_exp_valid(Payload) :-
  (
    get_dict(exp, Payload, ExpPayload)
  -> not_before_now(ExpPayload)
  ; !
  ).

jwt_aud_valid(Payload, Options) :-
  (
    option(aud(Aud), Options, ""),
    Aud \= ""
  -> Aud = Payload.aud
  ; !
  ).

jwt_iss_valid(_, Options) :-
  option(iss(""), Options, ""),
  !.

jwt_iss_valid(Payload, Options) :-
  IssPayload = Payload.get(iss),
  option(iss(Iss), Options, ""),
  Iss = IssPayload.

jwt_decode_from_string(Data, Payload, Key) :-
  member(Key.type, ['RSA', 'ECDSA']),
  !,
  jwt_decode_from_string(Data, Payload, Key.algorithm, Key.public_key),
  !.

jwt_decode_from_string(Data, Payload, Key) :-
  jwt_decode_from_string(Data, Payload, Key.algorithm, ''),
  !.

claims_with_iss(C, K, CNew) :-
  (
    _ = K.get(iss)
  -> CNew = C.put(_{iss: K.get(iss)})
  ; CNew = C
  ).

claims_with_iat(Claims, CNew) :-
  (
    _ = Claims.get(iat)
  -> CNew = Claims
  ; get_time(Now),
    NowT is floor(Now),
    CNew = Claims.put(_{iat: NowT})
  ).

claims_with_aud(Claims, CNew) :-
  (
    setting(audience, Audience),
    Audience \= ""
  -> CNew = Claims.put(_{aud: Audience})
  ; CNew = Claims
  ).

jwt_iat_valid(Payload) :-
  Iat = Payload.iat,
  Iat > 0,
  not_after_now(Iat).

not_before_now(Epoch) :-
  get_time(Now),
  setting(clock_tolerance, Tolerance),
  NowTolerated is Now - Tolerance,
  NowTolerated =< Epoch.

not_after_now(Epoch) :-
  get_time(Now),
  setting(clock_tolerance, Tolerance),
  NowTolerated is Now + Tolerance,
  NowTolerated > Epoch.

get_key_from_settings(Kid, Key) :-
  setting(keys, Keys),
  get_kid(Kid, Keys, Key).

get_kid(_, [], _) :- fail.
get_kid(Kid, [Key|_], KeyResult) :-
  Key.kid = Kid,
  read_key_file(Key, KeyResult),
  !.
get_kid(Kid, [_|Keys], KeyDict) :-
  get_kid(Kid, Keys, KeyDict).

read_key_file(Key, Key) :-
  Key.type = 'HMAC',
  !.
read_key_file(Key,KeyRead) :-
  member(Key.type, ['RSA', 'ECDSA']),
  get_dict('key', Key, PrivateKeyFile),
  !,
  read_file_to_string(PrivateKeyFile, KeyStr, []),
  read_file_to_string(Key.public_key, PublicKeyStr, []),
  atom_string(KeyAtom, KeyStr),
  atom_string(PublicKeyAtom, PublicKeyStr),
  KeyRead = Key.put(_{key: KeyAtom, public_key: PublicKeyAtom}),
  !.
read_key_file(Key, KeyRead) :-
  member(Key.type, ['RSA', 'ECDSA']),
  read_file_to_string(Key.public_key, PublicKeyStr, []),
  atom_string(PublicKeyAtom, PublicKeyStr),
  KeyRead = Key.put(_{public_key: PublicKeyAtom}),
  !.


get_key_file(File, Key) :-
  read_file_to_string(File, KeyStr, []),
  atom_string(Key, KeyStr).


wrap_key(PubKeyString, PadStart, PadWidth, StrLength, Acc, Output) :-
  NewPadStart is PadStart + PadWidth,
  (   NewPadStart < StrLength
  ->  sub_string(PubKeyString, PadStart, PadWidth, _, SubString),
      format(string(NewAcc), "~s~s~n", [Acc, SubString]),
      wrap_key(PubKeyString, NewPadStart, PadWidth, StrLength, NewAcc, Output)
  ;   sub_string(PubKeyString, PadStart, _, 0, SubString),
      string_concat(Acc, SubString, Output)
  ).

/* convert_jwt_to_key(+Key, -SettingsKey) is semidet.
 *
 * Converts a key from a JWKS endpoint to a key that is usable in the settings
 */
convert_jwk_to_key(Key, SettingsKey) :-
  Key.use = "sig", % key should be skipped if it is not sig
  Key.kty = "RSA", % only support RSA for the time being
  memberchk(PubKeyString, Key.x5c),
  string_length(PubKeyString, StrLength),
  wrap_key(PubKeyString, 0, 64, StrLength, "", WrappedKey),
  format(string(CertFormatted),
         "-----BEGIN CERTIFICATE-----~n~s~n-----END CERTIFICATE-----",
         [WrappedKey]),
  tmp_file_stream(text, FileTmpCert, TmpStreamCert),
  write(TmpStreamCert, CertFormatted),
  close(TmpStreamCert),
  process_create(path(openssl), ['x509', '-pubkey', '-in', FileTmpCert, '-noout'],
                 [
                  stdout(pipe(Stream)),
                  detached(false),
                  process(PID)
                 ]),
  tmp_file_stream(text, File, StreamTmp),
  copy_stream_data(Stream, StreamTmp),
  close(StreamTmp),
  close(Stream),
  process_wait(PID, _),
  atom_string(KidAtom, Key.kid),
  atom_string(AlgAtom, Key.alg),
  SettingsKey = _{kid: KidAtom,
                  type: 'RSA',
                  algorithm: AlgAtom,
                  public_key: File}.

/* setup_jwks(+Endpoint) is nondet.
 *
 * Sets up a JWKS endpoint to use and set the key settings accordingly.
 * Only supports RSA for now and be wary that it overwrites the existing
 * configuration.
 *
 * Another limitation so far is that this is quite inefficient, as the pubkey
 * is being written to a temporary file and then read again by the kid
 * predicate. This module should probably be refactored entirely.
 *
 * It also assumes the auth0 JWKS structure.
 */
setup_jwks(Endpoint) :-
  http_get(Endpoint, Data, [json_object(dict)]),
  maplist(convert_jwk_to_key, Data.keys, Keys),
  set_setting(jwt_io:keys, Keys).
