:- begin_tests(jwt_args).

:- use_module(prolog/jwt_io).

:- set_setting(jwt_io:keys, [
    k{kid: 'atom', type: 'HMAC', algorithm: 'HS256', key: 'weak_password'}
  ]).

test(jwt_encode, error(_)) :- jwt_encode("string", _{sub:a},_).

test(jwt_encode, error(_)) :- jwt_encode('atom', "string", _).

test(jwt_encode) :- jwt_encode(atom,_{sub:a},_).

:- end_tests(jwt_args).
