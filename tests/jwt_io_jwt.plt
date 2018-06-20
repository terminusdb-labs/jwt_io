:- begin_tests(jwt_io).

:- use_module(library(settings)).
:- use_module(library(http/json)).

:- use_module(prolog/jwt_io).

:- set_setting(jwt_io:keys, [
    k{kid: 'hmac256', type: 'HMAC', algorithm: 'HS256', key: 'weak_password'},
    k{kid: 'hmac384', type: 'HMAC', algorithm: 'HS384', key: 'weak_password'},
    k{kid: 'hmac512', type: 'HMAC', algorithm: 'HS512', key: 'weak_password'},
    k{kid: 'rsa256', type: 'RSA', algorithm: 'RS256', key: 'keys/rs.key', public_key: 'keys/rs.key.pub'},
    k{kid: 'rsa384', type: 'RSA', algorithm: 'RS384', key: 'keys/rs.key', public_key: 'keys/rs.key.pub'},
    k{kid: 'rsa512', type: 'RSA', algorithm: 'RS512', key: 'keys/rs.key', public_key: 'keys/rs.key.pub'},
    k{kid: 'ecdsa256', type: 'ECDSA', algorithm: 'ES256', key:'keys/ecdsa.pem', public_key: 'keys/ecdsa-pub.pem'},
    k{kid: 'ecdsa384', type: 'ECDSA', algorithm: 'ES384', key:'keys/ecdsa.pem', public_key: 'keys/ecdsa-pub.pem'},
    k{kid: 'ecdsa512', type: 'ECDSA', algorithm: 'ES512', key:'keys/ecdsa.pem', public_key: 'keys/ecdsa-pub.pem'}
  ]).
:- set_setting(jwt_io:clock_tolerance, 30).

test_encode_decode(Alg, Sub) :-
  jwt_encode(Alg, _{sub:'a'}, X),
  jwt_decode(X, Y, []),
  atom_json_dict(Y, Result, []),
  Sub = Result.get(sub).

test(hmac, true(Sub == "a")) :- test_encode_decode('hmac256', Sub).
test(hmac, true(Sub == "a")) :- test_encode_decode('hmac384', Sub).
test(hmac, true(Sub == "a")) :- test_encode_decode('hmac512', Sub).
test(rsa, true(Sub == "a")) :- test_encode_decode('rsa256', Sub).
test(rsa, true(Sub == "a")) :- test_encode_decode('rsa384', Sub).
test(rsa, true(Sub == "a")) :- test_encode_decode('rsa512', Sub).
test(ecdsa, true(Sub == "a")) :- test_encode_decode('ecdsa256', Sub).
test(ecdsa, true(Sub == "a")) :- test_encode_decode('ecdsa384', Sub).
test(ecdsa, true(Sub == "a")) :- test_encode_decode('ecdsa512', Sub).

test_encode_decode_iss(Payload, Options) :-
  jwt_encode('hmac256', Payload, X),
  jwt_decode(X, _, Options).

test(iss) :- test_encode_decode_iss( _{sub: 'a', iss: 'testiss'}, [iss("testiss")]).
test(iss, fail) :- test_encode_decode_iss( _{sub: 'a', iss: 'testiss'}, [iss("testissnot")]).
test(iss, fail) :- test_encode_decode_iss( _{sub: 'a'}, [iss("testissnot")]).
test(iss) :- test_encode_decode_iss( _{sub: 'a', iss: "testiss"}, []).

test_encode_decode_exp(Payload) :-
  jwt_encode('hmac256', Payload, X),
  jwt_decode(X, _, []).

test(exp) :- get_time(Exp), test_encode_decode_exp(_{sub: 'a', exp: Exp}).
test(exp, fail) :- get_time(Exp), setting(jwt_io:clock_tolerance, Tolerance), Exp1 is Exp - Tolerance - 100, test_encode_decode_exp(_{sub: 'a', exp: Exp1}).
test(exp) :- get_time(Exp), setting(jwt_io:clock_tolerance, Tolerance), Exp1 is Exp - Tolerance + 10, test_encode_decode_exp(_{sub: 'a', exp: Exp1}).
test(exp) :- get_time(Exp), setting(jwt_io:clock_tolerance, Tolerance), Exp1 is Exp + Tolerance - 10, test_encode_decode_exp(_{sub: 'a', exp: Exp1}).

test_encode_decode_nbf(Payload) :-
  jwt_encode('hmac256', Payload, X),
  jwt_decode(X, _, []).

test(nbf) :- get_time(Nbf), test_encode_decode_nbf(_{sub: 'a', nbf: Nbf}).
test(nbf, fail) :- get_time(Nbf), setting(jwt_io:clock_tolerance, Tolerance), Nbf1 is Nbf + Tolerance + 100, test_encode_decode_nbf(_{sub: 'a', nbf: Nbf1}).
test(nbf) :- get_time(Nbf), setting(jwt_io:clock_tolerance, Tolerance), Nbf1 is Nbf - Tolerance + 10, test_encode_decode_nbf(_{sub: 'a', nbf: Nbf1}).
test(nbf) :- get_time(Nbf), setting(jwt_io:clock_tolerance, Tolerance), Nbf1 is Nbf + Tolerance - 10, test_encode_decode_nbf(_{sub: 'a', nbf: Nbf1}).

test_encode_decode_iat(Iat) :-
  jwt_encode('hmac256', _{sub: 'a', iat: Iat}, X),
  jwt_decode(X, _, []).

test(iat) :- jwt_encode('hmac256', _{sub: 'a'}, X), jwt_decode(X, Y, []), atom_json_dict(Y, Result, []), _ = Result.get(iat).
test(iat, fail) :- test_encode_decode_iat(-1).
test(iat, fail) :- get_time(Now), setting(jwt_io:clock_tolerance, Tolerance), Iat is Now + Tolerance + 10, test_encode_decode_iat(Iat).
test(iat) :- get_time(Now), setting(jwt_io:clock_tolerance, Tolerance), Iat is Now + Tolerance - 10, test_encode_decode_iat(Iat).
test(iat) :- get_time(Now), setting(jwt_io:clock_tolerance, Tolerance), Iat is Now - Tolerance + 10, test_encode_decode_iat(Iat).

test(aud, fail) :- set_setting(jwt_io:audience, ""), jwt_encode('hmac256', _{sub: 'a'}, X), jwt_decode(X, Y, []), atom_json_dict(Y, Result, []), _ = Result.get(aud).
test(aud) :- set_setting(jwt_io:audience, "testaud"), jwt_encode('hmac256', _{sub: 'a'}, X), jwt_decode(X, Y, []), atom_json_dict(Y, Result, []), Aud = Result.get(aud), Aud = "testaud".
test(aud) :- set_setting(jwt_io:audience, "testaud"), jwt_encode('hmac256', _{sub: 'a'}, X), jwt_decode(X, _, [aud("testaud")]).
test(aud, fail) :- set_setting(jwt_io:audience, "testaudnot"), jwt_encode('hmac256', _{sub: 'a'}, X), jwt_decode(X, _, [aud("testaud")]).
test(aud) :- set_setting(jwt_io:audience, "testaudnot"), jwt_encode('hmac256', _{sub: 'a'}, X), jwt_decode(X, _, [aud("")]).

test(jti) :- jwt_encode('hmac256', _{sub: 'a'}, X), jwt_decode(X, _, []).
test(jti, fail) :- jwt_encode('hmac256', _{sub: 'a'}, X), jwt_decode(X, Y, []), jwt_decode(X, Y, []).
test(jti, fail) :- jwt_encode('hmac256', _{sub: 'a'}, X), jwt_decode(X, Y, []), not(jwt_decode(X, Y, [])), jwt_decode(X, Y, []).
