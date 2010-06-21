#! /usr/bin/php -q

<?php
/*******************************************************************\
*     gen_prompts - generating voice prompts using TTS engines
*
* $Revision$
*
* Copyright 2009, AMOOMA GmbH, Bachstr. 126, 56566 Neuwied, Germany,
* http://www.amooma.de/
* Stefan Wintermeyer <stefan.wintermeyer@amooma.de>
* Philipp Kempgen <philipp.kempgen@amooma.de>
* Peter Kozak <peter.kozak@amooma.de>
* Soeren Sprenger <soeren.sprenger@amooma.de>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public License
* as published by the Free Software Foundation; either version 2
* of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
* MA 02110-1301, USA.
\*******************************************************************/

# global constants
#
define( 'TEMP_FILE', 'vg_temp');

# global variables
#
$structure = Array(); // main strusture array
$voices = Array();    // voice prompt array
$verbose = false;
$html_table = false;
$languages = Array();

$option_defaults = Array(
	'w' => '/tmp/gen_prompts',
	'l' => 'de,en',
	'e' => 'file',
	'g' => 'mbrola {INFILE} {OUTFILE}',
	's' => '.wav',
	'f' => ''
);

#function definitions
#
function set_structure($key, $position) {
	global $structure;

	if ($key == '') return 0;

	$structure[$key] = $position;

}

function print_error($error_msg) {
	$fp = fopen ('php://stderr',"w");

	fprintf($fp, baseName(__FILE__). " ERROR: %s\n",$error_msg);

	fclose($fp);

}

function verbose($message) {
	global $verbose;

	if ($verbose) echo $message,"\n";
}

function print_usage($options) {
	
	echo 'Usage: '.baseName(__FILE__).' [options]'."\n\t";
	echo '-v : verbose mode - default is to be extremely silent'."\n\t";
	echo '-h : create html table and exit'."\n\t";
	echo '-w : set working directory - default: "/tmp/gen_prompts/'."\n\t";
	echo '-l : select output language(s) - default: "de,en"'."\n\t";
	echo '-e : select database engine - default: "file"'."\n\t";
	echo '-f : use CSV file as source'."\n\t";
	echo '-g : specify voice generator command - default: "mbrola {INFILE} {OUTFILE}"'."\n\t";
	echo '-s : specify output file suffixes - default:  ".wav"'."\n\n";
	
}

function read_csvfile($filename) {
	global $voices;
	global $structure;	

	$voice_entry = Array();

	$fp = fopen ($filename,"r");
	$i = 0;
	
	while ( ($data = fgetcsv ($fp, 2000, ";")) !== false ) { 
		
		if (($i == 0) && (is_Array($data)) && (count($data) > 1)) {
			foreach ($data as $position => $key) {
				if ($key) set_structure($key, $position);
			}
			$i++;
		} 
		else if ((is_Array($data)) && (count($data) > 1) && ($data[0] != '')) {
			if ($data[$structure['filename']] != '')  {
				foreach ($structure as $key => $position) {
					if (array_key_exists($position, $data)) $voice_entry[$key]=$data[$position];
				}
				$voices[] = $voice_entry;
				unset($voice_entry);
			}
			$i++;
		}
	}
	fclose ($fp);

}

function process_voice($voice_entry, $lang) {
	global $options;

	$timestamp = time();	

	$dirname = dirname($voice_entry['filename']);
	$work_path = $options['w'].'/'.$lang.'/';

	if ($dirname == '.') $dirname = '';

	if ($dirname) {
		if (is_dir($work_path.$dirname) == false) mkdir($work_path.$dirname);
	} 


	$fp = fopen ($work_path.TEMP_FILE,"w");
	
	if ($fp == NULL) { 
		print_error("cannot open file: ".$work_path.TEMP_FILE." for writing!");
		return 0;
	}

	fprintf($fp,'%s',$voice_entry[$lang]);

	fclose ($fp);
	
	$option_translations = Array(
		'{INFILE}'  => $work_path.TEMP_FILE,
		'{OUTFILE}' => $work_path.TEMP_FILE.$options['s']
	);

	$cmd = strtr($options['g'], $option_translations);

	$cmd_array =  explode('&&', $cmd);

	foreach ($cmd_array as $key => $cmd) {
		@exec( escapeShellCmd($cmd) .' 2>>/dev/null', $out, $err );
	
		if ($err) {
			print_error(" File processor: ".($key+1)." return code: $err on processing string \"".$voice_entry[$lang].'"');
		}
	}
	unlink($work_path.TEMP_FILE);
	if ((!file_exists($work_path.TEMP_FILE.$options['s'])) || (filemtime($work_path.TEMP_FILE.$options['s']) < $timestamp)) {	
		print_error(' Temporary voice file not created properly!');
		return 0;
	} 
	if (rename($work_path.TEMP_FILE.$options['s'], $work_path.$voice_entry['filename'].$options['s']) == false) {
		print_error(' Cannot rename file to '.$voice_entry['filename'].$options['s']);
		return 0;
	}
	
	return 1;
}

function process_sound($voice_entry, $lang) {

	if (array_key_exists('comment', $voice_entry)) {
		verbose("Processing of Sound [$lang] \"".$voice_entry['comment']."\" not implemented yet.");
	} else {
		verbose("Do not know how to handle file : ". $voice_entry['filename']);
	}
	return 0;
}


function process_language($lang) {
	global $voices;
	global $options;
	

	if (is_dir($options['w'].'/'.$lang) == false) {
		verbose('Create directory "'.$options['w'].'/'.$lang.'" ...');
		mkdir($options['w'].'/'.$lang);
	}
	foreach ($voices as $line => $voice_entry) {
		if (array_key_exists('type', $voice_entry) && ($voice_entry['type'] == 'sound')) {
			verbose("Processing soundfile \"".$voice_entry['filename']."\" ... ");
		
			

			process_sound($voice_entry, $lang);
		} else {
			if ($voice_entry[$lang] != '') {
				verbose("Processing [$lang] entry $line \"".$voice_entry[$lang]."\"... ");
				process_voice($voice_entry, $lang);
			} else {
				process_sound($voice_entry, $lang);
			}
		}
		
	}	

}

function html_table_output($languages) {
	global $voices;
	global $structure;

	echo "<table border=0>\n";
	echo "  <tr>\n";
		foreach ($structure as $key => $entry) {
			echo '    <th align="left" valign="top">'.htmlentities($key,ENT_QUOTES,'UTF-8')."</th>\n";
		}
	echo "  </tr>\n";	

	foreach ($voices as $line => $voice_entry) {
		echo "  <tr>\n";
		foreach ($voice_entry as $entry) {
			echo '    <td align="left" valign="top">'.htmlentities($entry,ENT_QUOTES,'UTF-8')."</td>\n";
		}
		echo "  </tr>\n";
	}
	echo "</table>\n";
}



# creating default structure
#
set_structure('filename',0);
set_structure('de',1);

#getting command line parameters
#
$options  = '';
$options .= 'v';  // verbose
$options .= 'h';  // html table output
$options .= 'w:'; // working directory
$options .= 'l:'; // language 
$options .= 'e:'; // source database engine
$options .= 'f:'; // source database file
$options .= 'g:'; // generator command
$options .= 's:'; // file suffix

$exit = 0;
$options = getopt($options);

if (count($options) == 0) print_usage($options);

$options = array_merge($option_defaults, $options);

if (array_key_exists('v', $options)) $verbose = true;
if (array_key_exists('h', $options)) $html_table = true;

verbose("PromptGenerator is generating Asterisk(R) voice prompts from database.");
verbose("\t(c) Copyright 2009, AMOOMA GmbH - Distributed under the terms of the GNU General Public License\n");


if (($options['e'] == 'file') && (($options['f'] == '') || (!file_exists($options['f'])))) {
	print_error('Input file "'.$options['f'].'" does not exist!');
	$exit = 1;
} 
if (($options['w'] == '') || (!is_dir($options['w']))) {
	print_error('Working directory "'.$options['w'].'" does not exist!');
	$exit = 1;
}

if (count($languages = explode(',',$options['l'])) == 0) {
	print_error('No languages specified!');
	$exit = 1;
}

if ($exit) die($exit);

if ($options['e'] == 'file') {

	# set default CSV file structure - will be merged with file header
	#
	set_structure('filename',0);
	set_structure('de',1);

	verbose('Processing CSV file "'.$options['f'].'" ...');
	read_csvfile($options['f']);

}

if ($html_table) {
	html_table_output($languages);
	exit(0);
}

foreach ($languages as $lang) {
	if (array_key_exists($lang, $structure)) process_language($lang);
}



?>
