# frozen_string_literal: true
# typed: false

require 'mkmf'

# Check for required headers
have_header('stdlib.h') or raise 'stdlib.h not found'
have_header('string.h') or raise 'string.h not found'

# Check for interned string functions (available in Ruby 2.3+)
have_func('rb_interned_str_cstr', 'ruby.h')
have_func('rb_enc_interned_str_cstr', 'ruby.h')
have_func('rb_enc_interned_str', 'ruby.h')
have_func('rb_locale_encoding', 'ruby/encoding.h')

# Create Makefile for arctic extension
create_makefile('arctic/arctic')
