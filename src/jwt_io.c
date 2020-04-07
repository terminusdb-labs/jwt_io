#include <SWI-Prolog.h>
#include <SWI-Stream.h>
#include <string.h>
#include <stdio.h>
#include <strings.h>
#include <jwt.h>

install_t install(void);

static void get_pl_arg_str(char *predicate_name, char *term_name, term_t term, char **out) {
	if (!PL_get_atom_chars(term, out)) {
		char           *warning;
		asprintf(&warning, "%s: instantiation fault (%s)", predicate_name, term_name);
		PL_warning(warning);
		free(warning);
	}
}

static foreign_t pl_jwt_encode(term_t in, term_t out, term_t key_term, term_t algorithm) {
    jwt_t *jwt;
    char *result, *grants, *alg_str, *key;
    int	rval;

    get_pl_arg_str("jwt_encode_from_string/4", "in", in, &grants);
    get_pl_arg_str("jwt_encode_from_string/4", "key", key_term, &key);
    get_pl_arg_str("jwt_encode_from_string/4", "algorithm", algorithm, &alg_str);
    jwt_new(&jwt);
    jwt_add_grants_json(jwt, grants);
    jwt_set_alg(jwt, jwt_str_alg(alg_str), (const unsigned char *)key, strlen(key));
    result = jwt_encode_str(jwt);
    rval = PL_unify_atom_chars(out, result);
    free(result);
    jwt_free(jwt);
    return rval;
}

static foreign_t pl_jwt_parse_head(term_t in, term_t head_term) {
    char *input, *head_payload;
    jwt_t *jwt;
    int	jwt_result;
    get_pl_arg_str("jwt_encode_from_string/4", "in", in, &input);

    jwt_result = jwt_decode(&jwt, input, NULL, 0);
    if (!jwt_result) {
        head_payload = jwt_get_headers_json(jwt, NULL);
        (void) PL_unify_atom_chars(head_term, head_payload);
        jwt_free(jwt);
        PL_succeed;
    }
    else {
        PL_fail;
    }
}

static foreign_t pl_jwt_decode(term_t in, term_t out_payload, term_t out_algorithm, term_t in_key) {
    char *input, *key, *payload;
    const char *algorithm;
    int jwt_result;
    jwt_t *jwt;

    get_pl_arg_str("jwt_encode_from_string/4", "in", in, &input);
    get_pl_arg_str("jwt_encode_from_string/4", "key", in_key, &key);
    if (key == NULL || !strcmp("", key)) {
        jwt_result = jwt_decode(&jwt, input, NULL, 0);
    } else {
        jwt_result = jwt_decode(&jwt, input, (const unsigned char *)key, strlen(key));
    }
    if (!jwt_result) {
        payload = jwt_get_grants_json(jwt, NULL);
        algorithm = jwt_alg_str(jwt_get_alg(jwt));
        (void) PL_unify_atom_chars(out_payload, payload);
        (void) PL_unify_atom_chars(out_algorithm, algorithm);
        free(payload);
        jwt_free(jwt);
        PL_succeed;
    } else {
        PL_fail;
    }
}

install_t install(void) {
    PL_register_foreign("jwt_parse_head", 2, pl_jwt_parse_head, 0);
    PL_register_foreign("jwt_encode_from_string", 4, pl_jwt_encode, 0);
    PL_register_foreign("jwt_decode_from_string", 4, pl_jwt_decode, 0);
}
