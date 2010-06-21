#!/usr/bin/php -q
<?php
#####################################################################
#                           Gemeinschaft
#                            repo tools
# 
# $Revision: 151 $
# 
# Copyright 2008-2009, amooma GmbH, Bachstr. 126, 56566 Neuwied,
# Germany, http://www.amooma.de/
# Philipp Kempgen <philipp.kempgen@amooma.de>
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#####################################################################

function my_log( $msg )
{
	echo "$msg\n";
}

# error levels introduced in newer versions of PHP:
if (! defined('E_STRICT'           )) define('E_STRICT'           , 1<<11); # since PHP 5
if (! defined('E_RECOVERABLE_ERROR')) define('E_RECOVERABLE_ERROR', 1<<12); # since PHP 5.2
if (! defined('E_DEPRECATED'       )) define('E_DEPRECATED'       , 1<<13); # since PHP 5.3
if (! defined('E_USER_DEPRECATED'  )) define('E_USER_DEPRECATED'  , 1<<14); # since PHP 5.3

function err_handler_die_on_err( $type, $msg, $file, $line )
{
	switch ($type) {
		case E_NOTICE:
		case E_USER_NOTICE:
		case E_DEPRECATED:
		case E_USER_DEPRECATED:
			if (error_reporting() != 0) {
				my_log( '[NOTICE] PHP: '. $msg .' in '. $file .' on line '. $line );
			} else {  # suppressed by @
				my_log( '[DEBUG] PHP: '. $msg .' in '. $file .' on line '. $line .' (suppressed)' );
			}
			break;
		case E_STRICT:
			if (error_reporting() != 0) {
				my_log( '[DEBUG] PHP (Strict): '. $msg .' in '. $file .' on line '. $line );
			} else {  # suppressed by @
				my_log( '[DEBUG] PHP (strict): '. $msg .' in '. $file .' on line '. $line );
			}
			break;
		case E_ERROR:
		case E_USER_ERROR:
			my_log( '[ERROR] PHP: '. $msg .' in '. $file .' on line '. $line );
			exit(1);
			break;
		case E_RECOVERABLE_ERROR:
			my_log( '[WARNING] PHP: '. $msg .' in '. $file .' on line '. $line );
			break;
		case E_WARNING:
		case E_USER_WARNING:
			if (error_reporting() != 0) {
				my_log( '[WARNING] PHP: '. $msg .' in '. $file .' on line '. $line );
				exit(1);
			} else {  # suppressed by @
				my_log( '[DEBUG] PHP: '. $msg .' in '. $file .' on line '. $line .' (suppressed)' );
			}
			break;
		default:
			my_log( '[WARNING] PHP: '. $msg .' in '. $file .' on line '. $line );
			exit(1);
			break;
	}
}
set_error_handler('err_handler_die_on_err');

function shutdown_fn()
{
	# log fatal E_ERROR errors which the error handler cannot catch
	if (function_exists('error_get_last')) {  # PHP >= 5.2
		$e = error_get_last();
		if (is_array($e)) {
			if ($e['type'] === E_ERROR) {  # non-catchable fatal error
				err_handler_die_on_err( $e['type'], $e['message'], $e['file'], $e['line'] );
			}
		}
	}
}
register_shutdown_function('shutdown_fn');



$conf = parse_ini_file( dirName(__FILE__).'/create-svn-tag.conf', false );
if (! is_array($conf)) exit(1);
$SVN_PROJECT_ROOT_URL     = array_key_exists('svn_project_root_url'    , $conf) ? $conf['svn_project_root_url'    ] : 'https://svn.example.com/myrepo';
$SVN_PROJECT_BRANCHES_DIR = array_key_exists('svn_project_branches_dir', $conf) ? $conf['svn_project_branches_dir'] : 'branches';
$SVN_PROJECT_TAGS_DIR     = array_key_exists('svn_project_tags_dir'    , $conf) ? $conf['svn_project_tags_dir'    ] : 'tags';
$SVN_USER                 = array_key_exists('svn_user'                , $conf) ? $conf['svn_user'                ] : '';
$SVN_PASS                 = array_key_exists('svn_pass'                , $conf) ? $conf['svn_pass'                ] : '';



@set_time_limit(0);

$SVN_BRANCH = '';
$SVN_TAG_SUB = '';
$SVN_TAG = '';

putenv('PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:'. getenv('PATH'));

if (! defined('STDIN')) {
	$STDIN = @fOpen('php://stdin', 'r');
	if ($STDIN) {
		define('STDIN', $STDIN);
		socket_set_blocking(STDIN, true);
		unset($STDIN);
	} else {
		echo "Could not open STDIN.\n";
		exit(1);
	}
}

function qsa( $str )
{
	return $str !== '' ? escapeShellArg($str) : '\'\'';
}

function display_header()
{
	passthru('clear 2>>/dev/null');
	//echo "\n";
	echo "#######################################################\n";
	echo "#            Gemeinschaft - create-svn-tag            #\n";
	echo "#######################################################\n";
	echo "\n";
}

function read_user_input( $trim=true )
{
	socket_set_blocking(STDIN, true);
	$in = rtrim(fgets(STDIN),"\n\r");
	if ($trim) $in = trim($in);
	return $in;
}

function ask( $question, $trim=true )
{
	echo $question, ':  ';
	
	# slurp abundant input
	socket_set_blocking(STDIN, false);
	while (fgetc(STDIN) !== false) {}
	socket_set_blocking(STDIN, true);
	
	return read_user_input($trim);
}

function find_branches()
{
	global $SVN_PROJECT_ROOT_URL, $SVN_PROJECT_BRANCHES_DIR, $SVN_USER, $SVN_PASS;
	static $branches = null;
	
	//echo "\n";
	echo "Suche nach Branches\n";
	echo "$SVN_PROJECT_ROOT_URL/$SVN_PROJECT_BRANCHES_DIR/* ...\n";
	if ($branches !== null) return $branches;
	$cmd = 'svn list --non-interactive --no-auth-cache'
		.' '. '--username '.qsa($SVN_USER) .' --password '.qsa($SVN_PASS)
		.' '. qsa("$SVN_PROJECT_ROOT_URL/$SVN_PROJECT_BRANCHES_DIR/");
	$err=0; $out=array();
	@exec($cmd, $out, $err);
	if ($err !== 0) {
		echo "[FEHLER] \"$SVN_PROJECT_ROOT_URL/$SVN_PROJECT_BRANCHES_DIR\" nicht gefunden.\n";
		return false;
	}
	sort($out, SORT_NUMERIC);
	$branches = array();
	foreach ($out as $i => $vers) {
		$vers = rtrim($vers, '/');
		if (! preg_match('/^[0-9](?:\.[0-9]+)*$/', $vers)) continue;
		$branches[] = $vers;
	}
	return $branches;
}

function find_tags()
{
	global $SVN_PROJECT_ROOT_URL, $SVN_PROJECT_TAGS_DIR, $SVN_BRANCH, $SVN_USER, $SVN_PASS;
	
	//echo "\n";
	echo "Suche nach Tags\n";
	echo "$SVN_PROJECT_ROOT_URL/$SVN_PROJECT_TAGS_DIR/$SVN_BRANCH.* ...\n";
	$cmd = 'svn list --non-interactive --no-auth-cache'
		.' '. '--username '.qsa($SVN_USER) .' --password '.qsa($SVN_PASS)
		.' '. qsa("$SVN_PROJECT_ROOT_URL/$SVN_PROJECT_TAGS_DIR");
	$err=0; $out=array();
	@exec($cmd, $out, $err);
	if ($err !== 0) {
		echo "[FEHLER] \"$SVN_PROJECT_ROOT_URL/$SVN_PROJECT_TAGS_DIR\" nicht gefunden.\n";
		return false;
	}
	sort($out, SORT_NUMERIC);
	$tags = array();
	foreach ($out as $i => $vers) {
		$vers = rtrim($vers, '/');
		if (! preg_match('/^[0-9](?:\.[0-9]+)*$/', $vers)) continue;
		if ('x'.substr($vers, 0, strlen($SVN_BRANCH)+1) !== 'x'.$SVN_BRANCH.'.') continue;
		$tags[] = $vers;
	}
	return $tags;
}

function ask_for_branch()
{
	global $SVN_PROJECT_ROOT_URL, $SVN_PROJECT_BRANCHES_DIR;
	
	$branches = find_branches();
	if (! is_array($branches) || count($branches)===0) {
		echo "[FEHLER] Keine Branches gefunden.\n";
		exit(1);
	}
	foreach ($branches as $branch) {
		echo "\t", $branch ,"\n";
	}
	echo "\n";
	$svn_branch_default = $branches[count($branches)-1];
	$svn_branch = ask( "Bitte geben Sie einen Branch ein [Default: $svn_branch_default]" );
	if ($svn_branch == '') $svn_branch = $svn_branch_default;
	$svn_branch = preg_replace('/[^0-9.]/', '', $svn_branch);
	return $svn_branch;
}

function ask_for_tag_sub()
{
	global $SVN_BRANCH;
	
	$tags = find_tags();
	if (count($tags)===0) {
		echo "(Noch keine Tags vorhanden.)\n";
		$svn_tag_default = "0";  # add ".0"
	} else {
		foreach ($tags as $tag) {
			echo "\t", $tag ,"\n";
		}
		$svn_tag_default = substr($tags[count($tags)-1], strlen($SVN_BRANCH)+1);
		
		# increment:
		$parts = explode('.', $svn_tag_default);
		if (count($parts) > 2) {
			echo "[FEHLER] $SVN_BRANCH.$svn_tag_default hat zu viele Unterversionen.\n";
			exit(1);
		}
		foreach ($parts as $i => $part) {
			$parts[$i] = (int)$part;
		}
		if (array_key_exists(1, $parts)) {
			$parts[1]++;
			if ($parts[1] > 9) {
				$parts[1] = 0;
				$parts[0]++;
			}
		} else {
			$parts[0]++;
		}
		$svn_tag_default = implode('.', $parts);
	}
	echo "\n";
	$svn_tag = ask( "Release-Version des zu erstellenden Tags von $SVN_BRANCH [Default: .$svn_tag_default]" );
	if ($svn_tag == '') $svn_tag = $svn_tag_default;
	$svn_tag = preg_replace('/^\.+/', '', $svn_tag);
	$svn_tag = preg_replace('/[^0-9.]/', '', $svn_tag);
	return $svn_tag;
}

function ask_for_permission( $a, $b )
{
	global $SVN_PROJECT_BRANCHES_DIR, $SVN_BRANCH, $SVN_PROJECT_TAGS_DIR, $SVN_TAG;
	
	echo "\n";
	echo "Wollen Sie jetzt vom Branch  $SVN_PROJECT_BRANCHES_DIR/$SVN_BRANCH\n";
	echo "                ein Release      $SVN_PROJECT_TAGS_DIR/$SVN_TAG  anlegen?\n";
	echo "\n";
	echo "Dann loesen Sie bitte folgende Mathe-Aufgabe:\n";
	$in = ask( "  $a+$b" );
	return (int)$in;
}



display_header();

$cmd = 'which svn';
$err=0; $out=array();
@exec($cmd, $out, $err);
if ($err !== 0) {
	if ($err === 127) {
		echo "[FEHLER] Befehl \"svn\" nicht gefunden.\n";
		exit($err);
	} else {
		echo "[FEHLER]\n";
		exit(1);
	}
}

do {
	$ok = false;
	$SVN_BRANCH = ask_for_branch();
	display_header();
	echo "Pruefe \"/$SVN_PROJECT_BRANCHES_DIR/$SVN_BRANCH\" ...\n";
	$cmd = 'svn list --non-interactive --no-auth-cache'
		.' '. '--username '.qsa($SVN_USER) .' --password '.qsa($SVN_PASS)
		.' '. qsa("$SVN_PROJECT_ROOT_URL/$SVN_PROJECT_BRANCHES_DIR/$SVN_BRANCH")
		.' 1>>/dev/null';
	$err=0; $out=array();
	@exec($cmd, $out, $err);
	if ($err !== 0) {
		echo "[FEHLER] \"$SVN_PROJECT_ROOT_URL/$SVN_PROJECT_BRANCHES_DIR/$SVN_BRANCH\" nicht gefunden.\n";
	} else {
		$ok = true;
		usleep(500);
		display_header();
	}
} while (! $ok);

do {
	$ok = false;
	$SVN_TAG_SUB = ask_for_tag_sub();
	$SVN_TAG = "$SVN_BRANCH.$SVN_TAG_SUB";
	display_header();
	if (! preg_match('/^[0-9](?:\.[0-9]+)*$/', $SVN_TAG_SUB)) {
		echo "[FEHLER] Version \"$SVN_TAG\" ist kein erlaubtes Format.\n";
	} else {
		echo "Pruefe \"/$SVN_PROJECT_TAGS_DIR/$SVN_TAG\" ...\n";
		$cmd = 'svn list --non-interactive --no-auth-cache'
			.' '. '--username '.qsa($SVN_USER) .' --password '.qsa($SVN_PASS)
			.' '. qsa("$SVN_PROJECT_ROOT_URL/$SVN_PROJECT_TAGS_DIR/$SVN_TAG")
			.' 1>>/dev/null 2>>/dev/null';
		$err=0; $out=array();
		@exec($cmd, $out, $err);
		if ($err === 0) {
			echo "[FEHLER] \"$SVN_PROJECT_ROOT_URL/$SVN_PROJECT_TAGS_DIR/$SVN_TAG\" existiert bereits.\n";
		} elseif ($err === 1) {
			$ok = true;
			usleep(500);
			display_header();
		} else {
			echo "[FEHLER]\n";
		}
	}
} while (! $ok);

do {
	$ok = false;
	srand(); $a = rand(1,10);
	srand(); $b = rand(1,10);
	$in = ask_for_permission( $a, $b );
	display_header();
	if ($in === $a + $b) {
		$ok = true;
		usleep(500);
		display_header();
	} else {
		echo "[FEHLER] Ungueltige Eingabe.\n";
	}
} while (! $ok);

usleep(500);
display_header();
sleep(2);
echo "Lege Tag $SVN_TAG an ...\n";
sleep(2);
$cmd = 'svn copy --non-interactive --no-auth-cache'
	.' '. '--username '.qsa($SVN_USER) .' --password '.qsa($SVN_PASS)
	.' -m '. qsa("version $SVN_TAG")
	.' '. qsa("$SVN_PROJECT_ROOT_URL/$SVN_PROJECT_BRANCHES_DIR/$SVN_BRANCH")
	.' '. qsa("$SVN_PROJECT_ROOT_URL/$SVN_PROJECT_TAGS_DIR/$SVN_TAG");
$err=0;
@passthru($cmd, $err);
if ($err !== 0) {
	echo "[FEHLER]\n";
	exit(1);
} else {
	usleep(500);
	display_header();
	echo "[OK] Tag $SVN_TAG angelegt.\n";
	echo "\n";
	echo "Mit\n";
	echo "make-tar.sh $SVN_TAG\n";
	echo "koennen Sie einen Tarball davon erstellen.\n";
	echo "\n";
}
exit(0);


