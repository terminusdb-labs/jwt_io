:- begin_tests(jwt_io).

:- use_module(library(settings)).
:- use_module(library(http/json)).

:- use_module(library(jwt_io)).

:- set_setting(jwt_io:clock_tolerance, 30).

test(pubpri_success, Sub == "a") :-
  set_setting(jwt_io:keys, [k{kid: 'rsa256', type: 'RSA', algorithm: 'RS256', key: 'keys/rs.key', public_key: 'keys/rs.key.pub'}]),
  jwt_encode('rsa256', _{sub:'a'}, X),
  jwt_decode(X, Y, []),
  atom_json_dict(Y, Result, []),
  Sub = Result.get(sub).

test(pubpri_fail, fail) :-
  set_setting(jwt_io:keys, [k{kid: 'rsa256', type: 'RSA', algorithm: 'RS256', key: 'keys/rs.key', public_key: 'keys/rs.key.pub'}]),
  jwt_encode('rsa256', _{sub:'a'}, X),
  set_setting(jwt_io:keys, [k{kid: 'rsa256', type: 'RSA', algorithm: 'RS256', key: 'keys/rs2.key', public_key: 'keys/rs2.key.pub'}]),
  jwt_decode(X, _, []).

test(pubonly_success, Sub == "a") :-
  set_setting(jwt_io:keys, [k{kid: 'rsa256', type: 'RSA', algorithm: 'RS256', key: 'keys/rs.key', public_key: 'keys/rs.key.pub'}]),
  jwt_encode('rsa256', _{sub:'a'}, X),
  set_setting(jwt_io:keys, [k{kid: 'rsa256', type: 'RSA', algorithm: 'RS256', public_key: 'keys/rs.key.pub'}]),
  jwt_decode(X, Y, []),
  atom_json_dict(Y, Result, []),
  Sub = Result.get(sub).

test(pubonly_fail, fail) :-
  set_setting(jwt_io:keys, [k{kid: 'rsa256', type: 'RSA', algorithm: 'RS256', key: 'keys/rs.key', public_key: 'keys/rs.key.pub'}]),
  jwt_encode('rsa256', _{sub:'a'}, X),
  set_setting(jwt_io:keys, [k{kid: 'rsa256', type: 'RSA', algorithm: 'RS256', public_key: 'keys/rs2.key.pub'}]),
  jwt_decode(X, _, []).

:- end_tests(jwt_io).
