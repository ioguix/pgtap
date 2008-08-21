\set ECHO
\set QUIET 1

--
-- Tests for pgTAP.
--
--
-- $Id$

-- Format the output for nice TAP.
\pset format unaligned
\pset tuples_only true
\pset pager

-- Create plpgsql if it's not already there.
SET client_min_messages = fatal;
\set ON_ERROR_STOP off
CREATE LANGUAGE plpgsql;

-- Keep things quiet.
SET client_min_messages = warning;

-- Revert all changes on failure.
\set ON_ERROR_ROLBACK 1
\set ON_ERROR_STOP true

-- Load the TAP functions.
BEGIN;
\i pgtap.sql
\set numb_tests 51

-- ## SET search_path TO TAPSCHEMA,public;

-- Set the test plan.
SELECT plan(:numb_tests);

-- Replace the internal record of the plan for a few tests.
UPDATE  __tcache__ SET value = 3 WHERE label = 'plan';

/****************************************************************************/
-- Test pass().
SELECT pass( 'My pass() passed, w00t!' );

-- Test fail().
\set fail_numb 2
\echo ok :fail_numb - Testing fail()
SELECT is(
       fail('oops'),
       E'not ok 2 - oops\n# Failed test 2: "oops"', 'We should get the proper output from fail()');

-- Check the finish() output.
SELECT is(
    (SELECT * FROM finish() LIMIT 1),
    '# Looks like you failed 1 test of 3',
    'The output of finish() should reflect the test failure'
);

/****************************************************************************/
-- Check num_failed
SELECT is( num_failed(), 1, 'We should have one failure' );
UPDATE __tresults__ SET ok = true, aok = true WHERE numb = :fail_numb;
SELECT is( num_failed(), 0, 'We should now have no failures' );

/****************************************************************************/
-- Check diag.
SELECT is( diag('foo'), '# foo', 'diag() should work properly' );
SELECT is( diag(E'foo\nbar'), E'# foo\n# bar', 'multiline diag() should work properly' );
SELECT is( diag(E'foo\n# bar'), E'# foo\n# # bar', 'multiline diag() should work properly with existing comments' );

/****************************************************************************/
-- Check no_plan.
DELETE FROM __tcache__ WHERE label = 'plan';
SELECT * FROM no_plan();
SELECT is( value, 0, 'no_plan() should have stored a plan of 0' )
  FROM __tcache__
 WHERE label = 'plan';

-- Set the plan to a high number.
DELETE FROM __tcache__ WHERE label = 'plan';
SELECT is( plan(4000), '1..4000', 'Set the plan to 4000' );
SELECT is(
    (SELECT * FROM finish() LIMIT 1),
    '# Looks like you planned 4000 tests but only ran 11',
    'The output of finish() should reflect a high test plan'
);

-- Set the plan to a low number.
DELETE FROM __tcache__ WHERE label = 'plan';
SELECT is( plan(4), '1..4', 'Set the plan to 4' );
SELECT is(
    (SELECT * FROM finish() LIMIT 1),
    '# Looks like you planned 4 tests but ran 9 extra',
    'The output of finish() should reflect a low test plan'
);

-- Reset the original plan.
DELETE FROM __tcache__ WHERE label = 'plan';
SELECT is( plan(:numb_tests), '1..' || :numb_tests, 'Reset the plan' );
SELECT is( value, :numb_tests, 'plan() should have stored the test count' )
  FROM __tcache__
 WHERE label = 'plan';

/****************************************************************************/
-- Test ok()
\echo ok 17 - ok() success
SELECT is( ok(true), 'ok 17', 'ok(true) should work' );
\echo ok 19 - ok() success 2
SELECT is( ok(true, ''), 'ok 19', 'ok(true, '''') should work' );
\echo ok 21 - ok() success 3
SELECT is( ok(true, 'foo'), 'ok 21 - foo', 'ok(true, ''foo'') should work' );

\echo ok 23 - ok() failure
SELECT is( ok(false), E'not ok 23\n# Failed test 23', 'ok(false) should work' );
\echo ok 25 - ok() failure 2
SELECT is( ok(false, ''), E'not ok 25\n# Failed test 25', 'ok(false, '''') should work' );
\echo ok 27 - ok() failure 3
SELECT is( ok(false, 'foo'), E'not ok 27 - foo\n# Failed test 27: "foo"', 'ok(false, ''foo'') should work' );

-- Clean up the failed test results.
UPDATE __tresults__ SET ok = true, aok = true WHERE numb IN( 23, 25, 27);

/****************************************************************************/
-- Test is().
\echo ok 29 - is() success
SELECT is( is(1, 1), 'ok 29', 'isa(1, 1) should work' );
\echo ok 31 - is() success 2
SELECT is( is('x'::text, 'x'::text), 'ok 31', 'is(''x'', ''x'') should work' );
\echo ok 33 - is() success 3
SELECT is( is(1.1, 1.10), 'ok 33', 'is(1.1, 1.10) should work' );
\echo ok 35 - is() success 4
SELECT is( is(1.1, 1.10), 'ok 35', 'is(1.1, 1.10) should work' );
\echo ok 37 - is() success 5
SELECT is( is(true, true), 'ok 37', 'is(true, true) should work' );
\echo ok 39 - is() success 6
SELECT is( is(false, false), 'ok 39', 'is(false, false) should work' );
--SELECT is( '12:45'::time, '12:45'::time, 'ok 41', 'is(time, time) should work' );
\echo ok 41 - is() success 7
SELECT is( is(1, 1, 'foo'), 'ok 41 - foo', 'is(1, 1, ''foo'') should work' );
\echo ok 43 - is() failure
SELECT is( is( 1, 2 ), E'not ok 43\n# Failed test 43\n#         have: 1\n#         want: 2', 'is(1, 2) should work' );

/****************************************************************************/
-- Test isnt().
\echo ok 45 - isnt() success
SELECT is( isnt(1, 2), 'ok 45', 'isnt(1, 2) should work' );
\echo ok 47 - isnt() failure
SELECT is( isnt( 1, 1 ), E'not ok 47\n# Failed test 47\n#     1\n#       <>\n#     1', 'is(1, 2) should work' );

-- Clean up the failed test results.
UPDATE __tresults__ SET ok = true, aok = true WHERE numb IN( 43, 47 );

/****************************************************************************/
-- Try using variables.
\set foo '\'' waffle '\''
\set bar '\'' waffle '\''
SELECT is( :foo::text, :bar::text, 'is() should work with psql variables' );

/****************************************************************************/
-- test multiline description.
\echo ok 50 - Multline diagnostics
SELECT is(
    ok( true, E'foo\nbar' ),
    E'ok 50 - foo\n# bar',
    'multiline desriptions should have subsequent lines escaped'
);

/****************************************************************************/
-- Finish the tests and clean up.
SELECT * FROM finish();
ROLLBACK;