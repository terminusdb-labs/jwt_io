:- begin_tests(jwt_io_unit).

:- use_module(library(settings)).
:- use_module(library(http/json)).

:- use_module(prolog/jwt_io).

test(get_key_file, Key = 'test 123\n\n---\n') :-
  jwt_io:get_key_file('tests/test_file', Key).

test(read_key_file, fail) :-
  jwt_io:read_key_file(_{type: 'NOSUCHTYPE'}, _).
test(read_key_file, Key = _{type:'HMAC'}) :-
  jwt_io:read_key_file(_{type: 'HMAC'}, Key).
test(read_key_file, Key = _{key:'test 123\n\n---\n',public_key:'test 1234\n\n---\n',type:'RSA'}) :-
  jwt_io:read_key_file(_{type: 'RSA', key: 'tests/test_file', public_key: 'tests/test_file2'}, Key).
test(read_key_file, Key = _{key:'test 123\n\n---\n',public_key:'test 1234\n\n---\n',type:'ECDSA'}) :-
  jwt_io:read_key_file(_{type: 'ECDSA', key: 'tests/test_file', public_key: 'tests/test_file2'}, Key).

test(get_kid, fail) :-
  jwt_io:get_kid('one', [], _).
test(get_kid, K = _{key:'test 123\n\n---\n',kid:one,public_key:'test 1234\n\n---\n',type:'ECDSA'}) :-
  jwt_io:get_kid('one', [_{type: 'ECDSA', key: 'tests/test_file', public_key: 'tests/test_file2', kid: 'one'},_{kid: 'onelast'}], K).

test(get_key_from_settings, K = _{key:'test 123\n\n---\n',kid:one,public_key:'test 1234\n\n---\n',type:'ECDSA'}) :-
  set_setting(jwt_io:keys, [_{type: 'ECDSA', key: 'tests/test_file', public_key: 'tests/test_file2', kid: 'one'},_{kid: 'onelast'}]),
  jwt_io:get_key_from_settings('one', K).

test(not_after_now) :- get_time(Now), jwt_io:not_after_now(Now).
test(not_after_now, fail) :- get_time(Now), Then is Now + 500000, jwt_io:not_after_now(Then).
test(not_after_now) :- get_time(Now), Then is Now - 500000, jwt_io:not_after_now(Then).

test(not_before_now) :- get_time(Now), jwt_io:not_before_now(Now).
test(not_before_now) :- get_time(Now), Then is Now + 500000, jwt_io:not_before_now(Then).
test(not_before_now, fail) :- get_time(Now), Then is Now - 500000, jwt_io:not_before_now(Then).

test(jwt_iat_valid, fail) :- jwt_io:jwt_iat_valid(_{ iat: 0}).
test(jwt_iat_valid, fail) :- jwt_io:jwt_iat_valid(_{ iat: -1}).
test(jwt_iat_valid) :- get_time(Now), jwt_io:jwt_iat_valid(_{ iat: Now}).

test(claims_with_aud, K = _{aud:"test_audience"}) :- set_setting(jwt_io:audience, "test_audience"), jwt_io:claims_with_aud(_{}, K).
test(claims_with_aud, K = _{}) :- set_setting(jwt_io:audience, ""), jwt_io:claims_with_aud(_{}, K).

test(claims_with_iat, K = _{iat:_}) :- jwt_io:claims_with_iat(_{}, K).
test(claims_with_iat, K = _{iat: 1}) :- jwt_io:claims_with_iat(_{iat: 1}, K).

test(claims_with_iss, K = _{iss: "testiss"}) :- jwt_io:claims_with_iss(_{}, _{iss: "testiss"}, K).
test(claims_with_iss, K = _{iss: "owniss"}) :- jwt_io:claims_with_iss(_{iss: "owniss"}, _{}, K).
test(claims_with_iss, K = _{iss: "testiss"}) :- jwt_io:claims_with_iss(_{iss: "owniss"}, _{iss: "testiss"}, K).

test(jwt_iss_valid) :- jwt_io:jwt_iss_valid(_{}, []).
test(jwt_iss_valid) :- jwt_io:jwt_iss_valid(_{}, [iss("")]).
test(jwt_iss_valid) :- jwt_io:jwt_iss_valid(_{iss: "xx"}, [iss("xx")]).
test(jwt_iss_valid, fail) :- jwt_io:jwt_iss_valid(_{iss: "xxx"}, [iss("xx")]).

test(jwt_aud_valid) :- jwt_io:jwt_aud_valid(_{}, []).
test(jwt_aud_valid) :- jwt_io:jwt_aud_valid(_{aud: "xx"}, [aud("xx")]).
test(jwt_aud_valid) :- jwt_io:jwt_aud_valid(_{aud: "xx"}, [aud("")]).

test(jwt_exp_valid) :- jwt_io:jwt_exp_valid(_{}).
test(jwt_exp_valid) :- get_time(Now), jwt_io:jwt_exp_valid(_{exp: Now}).
test(jwt_exp_valid) :- get_time(Now), Then is Now + 500000, jwt_io:jwt_exp_valid(_{exp: Then}).
test(jwt_exp_valid, fail) :- get_time(Now), Then is Now - 500000, jwt_io:jwt_exp_valid(_{exp: Then}).

test(jwt_nbf_valid) :- jwt_io:jwt_nbf_valid(_{}).
test(jwt_nbf_valid) :- get_time(Now), jwt_io:jwt_nbf_valid(_{nbf: Now}).
test(jwt_nbf_valid, fail) :- get_time(Now), Then is Now + 500000, jwt_io:jwt_nbf_valid(_{nbf: Then}).
test(jwt_nbf_valid) :- get_time(Now), Then is Now - 500000, jwt_io:jwt_nbf_valid(_{nbf: Then}).

:- end_tests(jwt_io_unit).
