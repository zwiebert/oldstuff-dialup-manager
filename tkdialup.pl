#! /usr/local/bin/perl -w

use strict;
use dm;

die unless defined $dm::state;

my $APPNAME="tkdialup";
my $applang="de"; # de | en
$0 =~ m!^(.*)/([^/]*)$! or die "path of program file required (e.g. ./$0)";
my ($progdir, $progname) = ($1, $2);
my $cfg_file="${progdir}/tkdialup.cfg";
my $cfg_file_usr=$ENV{"HOME"} . "/.tkdialup.cfg";

# constants
my $days_per_week = 7;
my $hours_per_day = 24;
my $mins_per_hour = 60;
my $mins_per_day = $mins_per_hour * $hours_per_day;
my $secs_per_min = 60;
my $secs_per_hour = $secs_per_min * $mins_per_hour;
my $secs_per_day = $secs_per_hour * $hours_per_day;

@dm::commands_on_startup = ();
@dm::commands_before_dialing = (\&clear_gui_counter, \&update_gui_dialing);
@dm::commands_on_connect = (\&main_window_iconify, \&update_gui_online);
@dm::commands_on_connect_failure = (\&update_gui_failure, \&clear_gui_counter);
@dm::commands_on_disconnect = (\&main_window_deiconify, \&update_gui_offline, \&update_gui_counter, \&update_progress_bar);

# Debug Aids
my $db_tracing = defined ($ENV{'DB_TRACING'});
sub db_trace ( $ ) {
    printf STDERR "trace %s\n", $_[0] if $db_tracing;
}

#### Locale ####
# Locale Defaults (English)
my @wday_names=('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');
my %LOC;
#---- File Menu
$LOC{'menu_file'}="File";
$LOC{'menu_file_hangup_now'}="Hangup now";
$LOC{'menu_file_hangup_now.help'}='Disconnect immediatly by issuing "Down Cmd"';
$LOC{'menu_file_hangup_defer'}="Hangup later";
$LOC{'menu_file_hangup_defer.help'}='Disconnect just before the current unit would end';
$LOC{'menu_file_save'}="Save Configuration";
$LOC{'menu_file_save.help'}='Keep all configuration changes permanently';
$LOC{'menu_file_quit'}="Quit";
$LOC{'menu_file_quit.help'}='Disconnect and terminate this "tkdialup" process immediatly.';
#---- Edit Menu
$LOC{'menu_edit'}="Edit";
$LOC{'menu_edit_options'}="Options";
$LOC{'menu_edit_options.help'}='Change Programm settings';
$LOC{'menu_edit_peer_options'}="Peer Options";
$LOC{'menu_edit_peer_options.help'}='Run a configuration editor. Its not full implemented yet
You can edit, apply and save  existing peer configurations like:
dialup command, hangup command, label, color, rate-name, visibility

You can show a rate but you cannot edit rates date.';
$LOC{'menu_edit_graph_options'}="Graph Options";
$LOC{'menu_edit_graph_options.help'}='Edit  background and ruler colors of graph window';
#---- View Menu
$LOC{'menu_view'}="View";
$LOC{'menu_view_graph'}="Graph";
$LOC{'menu_view_graph.help'}='Show time/money graphs of all active peers';
$LOC{'menu_view_clock'}="Show clock";
$LOC{'menu_view_progress_bar'}="Show progress bar";
$LOC{'menu_view_stat'}="Statistic ...";
$LOC{'menu_view_stat.help'}='Show a time/money history list for this user';
$LOC{'button_main_hangup'}="Hangup";
#---- Help Menu
$LOC{'menu_help'}="Help";
$LOC{'menu_help_about'}="About ...";
$LOC{'menu_help_about.help'}='Show information about this program and its author';
$LOC{'menu_help_balloon_help'}="Mouse Pointer Help";
$LOC{'menu_help_balloon_help.help'}='Toggle showing balloon help';
#---- Rate Window
$LOC{'win_rate_date_start'}='Start Date';
$LOC{'win_rate_date_start.help'}='Date when this rate became vaild (may be empty if next field is empty too)';
$LOC{'win_rate_date_end'}='End Date';
$LOC{'win_rate_date_end.help'}='Date when this rate became or will become invalid';
$LOC{'win_rate_weekdays'}='Weekdays';
$LOC{'win_rate_weekdays.help'}='Set of numbers (0..6) representing weekdays (Sun..Sat)';
$LOC{'win_rate_daytime_start'}='Start Time';
$LOC{'win_rate_daytime_start.help'}='Daytime on which this rate becomes valid (may be empty if next field is empty too)';
$LOC{'win_rate_daytime_end'}='End Time';
$LOC{'win_rate_daytime_end.help'}='Daytime on which tis rate becomes invalid (must end before midnight!)';
$LOC{'win_rate_money_per_min'}='M/min';
$LOC{'win_rate_money_per_min.help'}='Payment in money per minute (not per unit!)'; 
$LOC{'win_rate_secs_per_unit'}='secs/unit';
$LOC{'win_rate_secs_per_unit.help'}='Length of a unit in seconds';
$LOC{'win_rate_money_per_connect'}='M/Conn.';
$LOC{'win_rate_money_per_connect.help'}='Payment per connection (usually 0)';
$LOC{'win_rate_free_linkup'}='FL';
$LOC{'win_rate_free_linkup.help'}='Free DialUp (Paying starts not before PPP connection is up)';
$LOC{'win_rate_overlay_rate'}='OR';
$LOC{'win_rate_overlay_rate.help'}='Overlay Rate (this may be a additional payment with a different unit length)';
#--- Main Window
$LOC{'win_main_start'}="Start";
$LOC{'win_main_start.help'}="Hit a Button to Connect a Peer";
$LOC{'win_main_money'}="Money";
$LOC{'win_main_money.help'}="Real Time Money Counter";
$LOC{'win_main_rate'}="Rate";
$LOC{'win_main_rate.help'}="Money per Minute";
#---

# read in locale file (see ./locale-de for a german locale file)
if (open (LOC, "$progdir/locale-$applang")) {
    my $line=0;
    while (<LOC>) {
	++$line;
	if (/^wday_names\s*=\s*(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+$/) {
	    @wday_names=($1, $2, $3, $4, $5, $6, $7); 
	} elsif (/^([a-z_.]+)\s*=\s*(.+)\s*$/) {
	    my $key=$1;
	    my $val=$2;
	    if (defined $LOC{$key}) {
		$LOC{$key}=dm::unescape_string($val);
	    } else {
		print STDERR "$progdir/locale-$applang:$line: Unknown configuration key <$1>\n";
	    }
	}
    }
    close LOC;
}


## Tk-GUI
use strict;
use Tk;
use Tk::ROText;
use Tk::ProgressBar;
use Tk::Balloon;

##--- Protos
 sub db_trace ( $ );
 sub set_color_entry ($$);
 sub get_color_entry ( $ );
 sub update_gui_dial_state ( $ );
 sub update_gui_failure ();
 sub update_gui_offline ();
 sub update_gui_online ();
 sub update_gui_dialing ();
 sub update_progress_bar ();
 sub clear_gui_counter ();
 sub update_gui_counter ();
 sub update_gui_pfg_per_minute ( $ );
 sub update_gui_rtc ();
 sub rtc_max_width ();
 sub update_gui ();
 sub cb_dialup ( $ );
 sub cb_disconnect ();
 sub make_diagram ( $$$$ );
 sub make_gui_graphwindow ( $$ );
 sub make_gui_aboutwindow ();
 sub make_gui_statwindow ();
 sub make_gui_mainwindow ();
 sub main_window_iconify ();
 sub main_window_deiconify ();
 sub mask_widget ($$$$$$);
 sub edit_bt_ok($$$$);
 sub cost_mask_window ($$$$);
 sub cost_mask_window_old ($$$);
 sub cost_mask_data ($);
 sub parse_cost_mask_data ($);
 sub item_edit_bt($$);
 sub cfg_update_gadgets ($$);
 sub cfg_editor_window ($$);
 sub color_cfg_editor_window ($$);
 sub read_config ($);
 sub write_config ($);
##---

my %cfg_gui_default= (balloon_help => '1', show_rtc => '1', show_progress_bar => '1',
		      graph_bgcolor => 'Grey85', graph_nrcolor => 'Grey70', graph_ercolor => 'Grey55');
my %cfg_gui = %cfg_gui_default;
my $main_widget;
my @entries;
my %labels;
my $disconnect_button;

my %widgets;
my $rtc_widget;
my $pb_widget;
my ($offs_record, $offs_isp_widget, $offs_sum_widget, $offs_min_price_widget) = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
# data for config editors
my @cfg_labels = ('Name', 'Up Cmd', 'Down Cmd', 'Label', 'Farbe', 'Tarif', 'Visible');
my @cfg_types =  ('text', 'text',   'text',      'text', 'color', 'text',  'flag');


sub set_color_entry ($$) {
    my ($entry, $color) = @_;
    $entry->configure(-foreground => $color, -background => $cfg_gui{'graph_bgcolor'});
}
sub get_color_entry ( $ ) {
    my ($entry) = @_;
    $entry->cget('-foreground');
}

sub update_gui_dial_state ( $ ) {
    my ($color) = @_;
    foreach my $isp (@dm::isps) {
	next unless (dm::get_isp_flag_active ($isp));
	my $label =  $labels{$isp};
	if (defined $label) {
	    my $bg_color = ($isp ne $dm::isp_curr) ? $label->parent->cget('-background') : $color;
	    $label->configure(-background => $bg_color);
	}
    }
}

sub update_gui_failure () {
    update_gui_dial_state ('Red');
}

sub update_gui_offline () {
    update_gui_dial_state ('Grey');
}

sub update_gui_online () {
    update_gui_dial_state ('Cyan');
}

sub update_gui_dialing () {
    update_gui_dial_state ('Yellow');
}


sub update_progress_bar () {
    use integer;
    my $tem = (dm::db_time () - ($dm::time_start - $dm::ppp_offset)) % $dm::curr_secs_per_unit;
    my $percent_done =  ($tem * 100) / $dm::curr_secs_per_unit;
    $pb_widget->value($percent_done);

    no integer;
}


sub clear_gui_counter () {
    while (my ($isp, $wid) = each (%widgets)) {
	my $entry=$$wid[$offs_sum_widget];
	$entry->delete ('1.0', 'end');
	$entry->configure (-background => $entry->parent->cget('-background'));

# FIXME: move the following
	if ($dm::state == $dm::state_dialing and $isp eq $dm::isp_curr) {
#	    $entry->insert('1.0', 'dialing');
	    $entry->configure (-background => 'Yellow');
	}
    }
}

sub update_gui_counter () {
    my @sums;
    my %sum_cache;

    while (my ($isp, $wid) = each (%widgets)) {
	my $sum = dm::get_sum ($isp);
	$sums[$#sums+1] = $sum;
	$sum_cache{$isp} = $sum;
    }

    @sums = sort {$a <=> $b} @sums;
    my $cheapest = $sums[$[];
    my $most_expensive = $sums[$#sums];

    while (my ($isp, $wid) = each (%widgets)) {
	my $price = $sum_cache{$isp};
	my $entry=$$wid[$offs_sum_widget];
	$entry->delete ('1.0', 'end');
	$entry->insert('1.0', sprintf ("%4.2f Pfg", $price));
	my $bg_color = (($cheapest == $price) ? 'Green'
			: (($most_expensive == $price) ? 'OrangeRed'
			   : 'Yellow'));
	$entry->configure (-background => $bg_color);
    }
}

sub update_gui_pfg_per_minute ( $ ) {
    my ($curr_time)=@_;
    while (my ($isp, $wid) = each (%widgets)) {
	my $widget=$$wid[$offs_min_price_widget];
	$widget->delete ('1.0', 'end');
	$widget->insert('1.0', sprintf ("%.2f", Dialup_Cost::calc_price (dm::get_isp_tarif($isp), $curr_time, 60)));
    }
}

sub update_gui_rtc () {
    $rtc_widget->delete ('1.0', 'end');
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime (time ());
    $rtc_widget->insert('1.0', sprintf (" %s  %u-%02u-%02u  %02u:%02u:%02u",
					$wday_names[$wday],
					$year + 1900, $mon + 1, $mday,
					$hour, $min, $sec,
					)); 
}
sub rtc_max_width () {
    my $max_wday_len=0;
    my $rtc_time_len=24;
    foreach my $wday (@wday_names) {
	if ((my $len = length ($wday)) > $max_wday_len) { $max_wday_len = $len; }
    }
    $max_wday_len + $rtc_time_len;
}

sub update_gui () {
    my $curr_time = dm::db_time();
    my $state = $dm::state;

    if ($main_widget->state eq 'normal') {
	if ($state == $dm::state_online or $state == $dm::state_dialing) {
	    $disconnect_button->configure(-state => 'normal');
	} else {
	    $disconnect_button->configure(-state => 'disabled');
	}
	update_gui_counter () if ($state == $dm::state_online);
	update_gui_pfg_per_minute ($curr_time);
	update_gui_rtc ();
	update_progress_bar () if ($state == $dm::state_online);
    }

}

sub cb_dialup ( $ ) {
    my ($isp) = @_;
    cb_disconnect ();
    dm::dialup ($isp);
}

sub cb_disconnect () {
  dm::disconnect ();
    # remove highlight on isp labels
    foreach my $isp (@dm::isps) {
	next unless (dm::get_isp_flag_active ($isp));

	my $label =  $labels{$isp};
	if (defined $label) {
	    my $bg_color = ($isp ne $dm::isp_curr) ? $label->parent->cget('-background') : 'Grey';
	    $label->configure(-background => $bg_color);
	}
    }
    0;
}

## display time/money graphs
sub make_diagram ( $$$$ ) {
    my ($win, $canvas, $xmax, $ymax) = @_;
    my ($width, $height) = ($canvas->width - 60, $canvas->height - 60);
    my ($xscale, $yscale) = ($width/$xmax, $height/$ymax); # convinience
    my ($xoffs, $yoffs) = (30, -30);

    $canvas->delete($canvas->find('all'));

    # print vertical diagram lines and numbers
    for (my $i=0; $i <= $xmax; $i+=60) {
	my $x = $i * $xscale + $xoffs;
	$canvas->createLine($x, -$yoffs, $x, -$yoffs + $height,
			    -fill => ($i%300) ? $cfg_gui{'graph_nrcolor'} : $cfg_gui{'graph_ercolor'});
	if (($i%300) == 0) {
	    $canvas->createText($x, $height - $yoffs + 10,
				-text => sprintf ("%u",  $i / 60));
	}
    }

    # print horizontal diagram lines and numbers
    for (my $i=0; $i <= $ymax; $i+=10) {
	my $y = -($i * $yscale + $yoffs - $height);
	$canvas->createLine($xoffs, $y, $width + $xoffs,  $y,
			    -fill => ($i%50) ? $cfg_gui{'graph_nrcolor'} : $cfg_gui{'graph_ercolor'});
	if (($i%50) == 0) {
	    $canvas->createText(10, $y, -text => sprintf ("%0.1f", $i / 100));
	}
    }

    # print labels in matching color
    if (1) {
	my $y=40;
	foreach my $isp (@dm::isps) {
	    next unless (dm::get_isp_flag_active ($isp));

	    $canvas->createText(40, $y,
				-text => dm::get_isp_label($isp),
				-anchor => 'w',
				-fill => dm::get_isp_color($isp));
	    
	    $y+=13;
	}
    }

    # print graphs in matching color
    foreach my $isp (reverse (@dm::isps)) {
	next unless (dm::get_isp_flag_active ($isp));
	my $time=dm::db_time();
	my $restart_x=0; 
	my $restart_y=0;
	my $part_of_previous_rate=0;
      restart: {
	  my $restart_x1=$restart_x;
	  my $restart_y1=$restart_y;
	  $restart_x = 0; $restart_y = 0;
	  my $flag_do_restart=0;
	  my @graphs=();
	  my @args=();
	  my @tmp =Dialup_Cost::tarif (dm::get_isp_tarif($isp), $time + $restart_x1);
	  my $tar = $tmp[0];   # rate list
	  my $swp = $tmp[2];   # absolute switchpoints (time of changing rates)
	  my ($x, $y) = (0, 0);
	  my $is_linear=1;
	  my @data=();
	  my $next_switch=9999999999;
	  foreach my $a (@$tar) {
	      my $offs_time = $$a[$Dialup_Cost::offs_sw_start_time] * $dm::ppp_offset;
	      my $offs_units; { use integer;  $offs_units =  $offs_time / $$a[$Dialup_Cost::offs_secs_per_clock] + 1};
	      my $sum += $offs_units * $$a[$Dialup_Cost::offs_pfg_per_clock] + $$a[$Dialup_Cost::offs_pfg_per_connection];
	      foreach my $i (@$swp) {
		  $next_switch = $i if ($next_switch > $i);
	      }
	      if ($$a[$Dialup_Cost::offs_secs_per_clock] <= 1) {
		  # handle pseudo linear graphs (like 1 second per clock) ###############################
		  my $xmax2 =  $xmax;
		  if ($next_switch < $xmax) {
		       $restart_x = $xmax2 = $next_switch;
		      die if $restart_x < $restart_x1;
		      $flag_do_restart=1;
		  }
		  if (! $restart_x1) {
		      $graphs[$#graphs+1]
			  = [ 0, $sum,
			      $xmax2, $sum + $xmax2 *  $$a[$Dialup_Cost::offs_pfg_per_clock] / $$a[$Dialup_Cost::offs_secs_per_clock] ];
		  } else {
		      $graphs[$#graphs+1]
			  = [ $restart_x1, 0,
			      $xmax2, ($xmax2 - $restart_x1) *  $$a[$Dialup_Cost::offs_pfg_per_clock] / $$a[$Dialup_Cost::offs_secs_per_clock] ];
		  }

	      } else {
		  # handle stair graphs (like 150 seconds per clock) ######################################
		  my @g = ($restart_x1) ? ()              : (0, $sum);
		  my $u = ($restart_x1) ? 0               : $offs_units+1;
		  my $i = ($restart_x1) ? $restart_x1 + 1 : $$a[$Dialup_Cost::offs_secs_per_clock]  - $offs_time;

		  while (($i <= $xmax) or ($i - $restart_x1 > $next_switch)) { # FIXME
		      if ($i - $restart_x1 > $next_switch) { # switchpoint reached
			  $restart_x = $next_switch;
			  $flag_do_restart = 1;
			  $part_of_previous_rate 
			      = (($next_switch - ($i - $restart_x1 -  $$a[$Dialup_Cost::offs_secs_per_clock]))
				 ) / $$a[$Dialup_Cost::offs_secs_per_clock];
			  last;
		      }
		      $g[$#g+1] = $i-1;
		      $g[$#g+1] = $#g > 1 ? $g[$#g-1] : 0;
		      $g[$#g+1] = $i;
		      $g[$#g+1] = $u++ * $$a[$Dialup_Cost::offs_pfg_per_clock];

		      $i+= $$a[$Dialup_Cost::offs_secs_per_clock] * (1 - $part_of_previous_rate);
		      $part_of_previous_rate = 0;
		  }
		  if (! $flag_do_restart) {
		      if ($i != $xmax) {
			  $g[$#g+1] = $xmax;
			  $g[$#g+1] = $g[$#g-1];
		      }
		  } else {
		      # we need common last x  for add_graph()
		      $g[$#g+1] = $next_switch;
		      $g[$#g+1] = $g[$#g-1];
		  }
		  $graphs[$#graphs+1] = \ @g;
	      }
	  }
	  my $gref =  $graphs[0];
	  my @graph = @$gref;
	  if ($#graphs > 0) {
	      for (my $i=1; $i <= $#graphs; $i++) {
		  @graph = add_graphs ($gref, $graphs[$i]);
	      }
	  }
	  for (my $i=1; $i <= $#graph; $i+=2) {
	      $graph[$i] += $restart_y1;
	  }
	  {
	      my $t=0;
	      foreach my $i (@graph) {
		  if (++$t%2) {
		      $args[$#args+1] = $i * $xscale + $xoffs;
		  } else {
		      # y
		      $args[$#args+1] = -($i * $yscale - $height + $yoffs);
		  }
	      }
	  }

	  $args[$#args+1] = '-fill';
	  $args[$#args+1] = dm::get_isp_color($isp);
	  $canvas->createLine (@args);

	  if ($flag_do_restart) {
	      $restart_y = $graph[$#graph];
	      goto restart if $flag_do_restart;
	  }
      }
    }
}

sub make_gui_graphwindow ( $$ ) {
    my ($xmax, $ymax) = @_; #(30 * $secs_per_min, 200);
    my ($width, $height) = (500, 350);
    my ($xscale, $yscale) = ($width/$xmax, $height/$ymax); # convinience
    my ($xoffs, $yoffs) = (20, -20);
    my $win=$main_widget->Toplevel;
    $win->title("$APPNAME: Graph");
    my $canvas=$win->Canvas(-width => $width + 40, -height => $height + 40, -background => $cfg_gui{'graph_bgcolor'});
    $canvas->pack(-expand => 1, -fill => 'both');
    $canvas->Tk::bind('<Configure>' => sub { make_diagram ($win, $canvas, $xmax, $ymax) });
}

## display about window
sub make_gui_aboutwindow () {
    my $win=$main_widget->Toplevel;
    my ($width, $height) = (200, 200);

    my ($about_txt, $about_lines, $about_columns) = ("", 0, 0);
    if (open (ABT, "$progdir/about-$applang")) {
	while (<ABT>) {
	    $about_txt .= $_;
	    $about_lines++;
	    my $len = length($_);
	    $about_columns = $len if ($len > $about_columns);
	}
	close (ABT);
    }
    chomp $about_txt;

    $win->title("$APPNAME: About");
    my $txt = $win->ROText(-height => $about_lines,
			   -width => $about_columns,
			   -wrap => 'none'
			   );
    $txt->pack();
    $txt->insert('end', $about_txt);

}

## display money and time statisctics from user owned logfile
sub make_gui_statwindow () {
    my $win=$main_widget->Toplevel;
    my ($width, $height) = (200, 200);

    my ($stat_txt, $stat_lines, $stat_columns) = ("", 0, 0);
    if (open (STA, "$progdir/stat_new.pl < $dm::cost_out_file |")) {
	while (<STA>) {
	    $stat_txt .= $_;
	    $stat_lines++;
	    my $len = length($_);
	    $stat_columns = $len if ($len > $stat_columns);
	}
	close (STA);
    }
    chomp $stat_txt;

    $win->title("$APPNAME: Stat");
    my $txt = $win->ROText(-height => $stat_lines,
			   -width => $stat_columns,
			   -wrap => 'none'
			   );
    $txt->pack();
    $txt->insert('end', $stat_txt);
}

sub make_gui_mainwindow () {
    $main_widget = MainWindow->new;
    $main_widget->title("$APPNAME");
    $main_widget->resizable (0, 0);
    my $balloon = $main_widget->Balloon();
    #### Menu ####
    my $menubar = $main_widget->Frame (-relief => 'raised');
    my $file_menu_bt = $menubar->Menubutton (-text => $LOC{'menu_file'});
    my $file_menu = $file_menu_bt->Menu();
    $file_menu_bt->configure (-menu => $file_menu);
    my $edit_menu_bt = $menubar->Menubutton (-text => $LOC{'menu_edit'});
    my $edit_menu = $edit_menu_bt->Menu();
    $edit_menu_bt->configure (-menu => $edit_menu);
    my $view_menu_bt = $menubar->Menubutton (-text => $LOC{'menu_view'});
    my $view_menu = $view_menu_bt->Menu();
    $view_menu_bt->configure (-menu => $view_menu);
    my $help_menu_bt = $menubar->Menubutton (-text => $LOC{'menu_help'});
    my $help_menu = $help_menu_bt->Menu();
    $help_menu_bt->configure (-menu => $help_menu);

#    $file_menu->command (-label => 'Speichern');
    $file_menu->command (-label => $LOC{'menu_file_hangup_now'}, -command => sub { cb_disconnect () });
    $file_menu->add ('checkbutton',
		     -label =>  $LOC{'menu_file_hangup_defer'},
		     -variable => \$dm::flag_stop_defer);
		    

    $file_menu->command (-label => $LOC{'menu_file_save'}, -command => sub { write_config($cfg_file_usr); });
    $file_menu->command (-label => $LOC{'menu_file_quit'}, -command => sub { cb_disconnect () ; exit });

    $edit_menu->command (-label => $LOC{'menu_edit_peer_options'}, -command => sub { cfg_editor_window (100,200) });
    $edit_menu->command (-label => $LOC{'menu_edit_graph_options'}, -command => sub { color_cfg_editor_window (100,200) });

    $view_menu->command (-label => "$LOC{'menu_view_graph'} 5 min ...", -command => sub {make_gui_graphwindow(5 * $secs_per_min, 50) });
    $view_menu->command (-label => "$LOC{'menu_view_graph'} 15 min ...", -command => sub {make_gui_graphwindow(15 * $secs_per_min, 100) });
    $view_menu->command (-label => "$LOC{'menu_view_graph'} 30 min ...", -command => sub {make_gui_graphwindow(30 * $secs_per_min, 200) });
    $view_menu->command (-label => "$LOC{'menu_view_graph'} 1 h ...", -command => sub {make_gui_graphwindow(1 * $secs_per_hour, 400) });
#    $view_menu->command (-label => "$LOC{'menu_view_graph'} 2 h ...", -command => sub {make_gui_graphwindow(2 * $secs_per_hour, 800) });
    $view_menu->add ('separator');
    $view_menu->command (-label => $LOC{'menu_view_stat'}, -command => sub {make_gui_statwindow() });
    $view_menu->add ('separator');
    $view_menu->add ('checkbutton', -label => $LOC{'menu_view_clock'},
		     -variable => \$cfg_gui{'show_rtc'},
		     -command => sub { if (!defined $rtc_widget->manager) { $rtc_widget->pack(-side => 'top'); }
				       else { $rtc_widget->packForget(); } });

    $view_menu->add ('checkbutton', -label => $LOC{'menu_view_progress_bar'},
		     -variable => \$cfg_gui{'show_progress_bar'},
		     -command => sub { if (!defined $pb_widget->manager) {
			                  $pb_widget->pack(-expand => 1, -fill => 'x');
				       } else { $pb_widget->packForget(); } });

    $help_menu->add ('checkbutton', -label => $LOC{'menu_help_balloon_help'},
		     -variable => \$cfg_gui{'balloon_help'},
		     -command => sub {
			 $balloon->configure(-state => ($cfg_gui{'balloon_help'} ? 'balloon' : 'none')); });
    $balloon->configure(-state => ($cfg_gui{'balloon_help'} ? 'balloon' : 'none'));

    $help_menu->add ('separator');
    $help_menu->command (-label => $LOC{'menu_help_about'}, -command => sub {make_gui_aboutwindow() });

    $balloon->attach($file_menu,
		     -state => 'balloon',
		     -msg => ['',
			      $LOC{'menu_file_hangup_now.help'},
			      $LOC{'menu_file_hangup_defer.help'},
			      $LOC{'menu_file_save.help'},
			      $LOC{'menu_file_quit.help'},
			      ],
                     );
    $balloon->attach($edit_menu,
		     -state => 'balloon',
		     -msg => ['',
			      $LOC{'menu_edit_peer_options.help'},
			      $LOC{'menu_edit_graph_options.help'},
			      $LOC{'menu_edit_options.help'},
			      ],
                     );
    $balloon->attach($view_menu,
		     -state => 'balloon',
		     -msg => ['',
			      $LOC{'menu_view_graph.help'},
			      $LOC{'menu_view_graph.help'},
			      $LOC{'menu_view_graph.help'},
			      $LOC{'menu_view_graph.help'},
			      '',
			      $LOC{'menu_view_stat.help'},
			      '',
			      'Enable/disable a digital clock',
			      ],);

    $balloon->attach($help_menu,
		     -state => 'balloon',
		     -msg => ['',
			      $LOC{'menu_help_balloon_help.help'},
			      '',
			      $LOC{'menu_help_about.help'},
			      ],
                     );

    $menubar->pack(-expand => 1, -fill => 'x');
    $file_menu_bt->pack(-side => 'left');
    $edit_menu_bt->pack(-side => 'left');
    $view_menu_bt->pack(-side => 'left');
    $help_menu_bt->pack(-side => 'right');

    #### RTC ####
    my $rtc_frame = $main_widget->Frame;
    $rtc_widget = $rtc_frame->ROText(-height => 1, -width => rtc_max_width (), -takefocus => 0, -insertofftime => 0);

    $rtc_frame->pack(-expand => 1, -fill => 'both' );
    $rtc_widget->pack(-expand => 1, -fill => 'x') if $cfg_gui{'show_rtc'};

    #### Controls ####
	my $button_frame = $main_widget->Frame;
    {
	my $row=0;
	my $usepack=0;

	unless ($usepack) {
	    my $label;
	    $label=$button_frame->Label(-text => $LOC{'win_main_start'})->grid(-row => $row, -column => 0);
	    $balloon->attach($label, -balloonmsg => $LOC{'win_main_start.help'}) if $balloon;
	    $label=$button_frame->Label(-text => $LOC{'win_main_money'})->grid(-row => $row, -column => 1);
	    $balloon->attach($label, -balloonmsg => $LOC{'win_main_money.help'}) if $balloon;
	    $label=$button_frame->Label(-text => $LOC{'win_main_rate'})->grid(-row => $row, -column => 2);
	    $balloon->attach($label, -balloonmsg => $LOC{'win_main_rate.help'}) if $balloon;
	    $row++;
	}
	foreach my $isp (@dm::isps) {
	    next unless (dm::get_isp_flag_active ($isp));
	    my $frame = $usepack ? $button_frame->Frame : $button_frame;
		
	    my $cmd_button = $frame->Button(-text => dm::get_isp_label ($isp),
				       -command => sub{ cb_dialup ($isp) } );
	    my $text = $frame->ROText(-height => 1, -width => 10, -takefocus => 0, -insertofftime => 0);
	    my $min_price = $frame->ROText(-height => 1, -width => 5, -takefocus => 0, -insertofftime => 0);

	    $cmd_button->configure(-background => 'Cyan') if ($isp eq $dm::isp_curr);

	    if ($usepack) {
		$cmd_button->pack(-expand => 1, -fill => 'x', -side => 'left');
		$min_price->pack(-side => 'right');
		$text->pack(-side => 'right');
		$frame->pack(-expand => 1, -fill => 'x');
	    } else {
		$cmd_button->grid(-column => 0, -row => $row, -sticky => "ew");
		$text->grid(-column => 1, -row => $row, -sticky => "ew");
		$min_price->grid(-column => 2, -row => $row, -sticky => "ew");
	    }
	    $entries[$#entries+1] = $text;
	    $labels{$isp} = $cmd_button;
	    $widgets{$isp} = [0, $cmd_button, $text, $min_price];
	    $row++;
	}
	    $button_frame->pack(-expand => 1, -fill => 'x');
    }
    my @tmp = $button_frame->gridBbox;
    db_trace ("@tmp");

    #### Progress Bar ####
    {
	my $pb_frame=$main_widget->Frame();
	my $pb = $pb_frame->ProgressBar
	    (
#	     -length => 220,
	     -width => 8,
	     -from => 100,
	     -to => 0,
	     -blocks => 10,
	     -colors => [0, 'green', 50, 'yellow' , 80, 'red'],
#	     -variable => \$percent_done,
#	     -relief => 'sunken',
	     -pady => 1,
	     -padx => 1,
	     );
	$pb->pack(-expand => 1, -fill => 'x') if $cfg_gui{'show_progress_bar'};
	$pb_widget = $pb;
	$pb_frame->pack(-expand => 1, -fill => 'x');
    }
    {
	my $frame = $main_widget->Frame;
	my $b1 = $frame->Button(-text => "$LOC{'button_main_hangup'}", -command => sub{cb_disconnect});
	$balloon->attach($b1, -balloonmsg => 'Disconnect immediatly by issuing "Down Cmd"') if $balloon;
	my $b2 = $frame->Button(-text => 'Graph', -command => sub{make_gui_graphwindow(30 * $secs_per_min, 200)});
	my $b3 = $frame->Button(-text => 'Exp-Graph', -command => sub{exp_make_gui_graphwindow()});
	
	$b1->pack(-expand => 1, -fill => 'x', -side => 'left');
#	$b2->pack(-expand => 1, -fill => 'x',  -side => 'left');
#	$b3->pack(-expand => 1, -fill => 'x',  -side => 'left') if defined &exp_make_gui_graphwindow;
	$frame->pack(-expand => 1, -fill => 'x');
	$disconnect_button=$b1;
    }
    $main_widget->repeat (1000, sub{update_gui()});
    $main_widget->repeat (1000, sub{dm::tick()});


    if ($dm::state == $dm::state_startup) {
	dm::state_trans_startup_to_offline ();
   }
    if ($dm::db_ready) {
	state_trans_offline_to_dialing ();
#	state_trans_dialing_to_online ();
    }
}

sub main_window_iconify () {
    $main_widget->iconify;
}
sub main_window_deiconify () {
    $main_widget->deiconify;
}

# config editor gui
=pod

=head2 NAME

mask_widget() - produce pairs of key/value-widgets

=head2 PARAMETERS and RESULT

=over 4

=item MASK_FRAME - Created widgets will be direct childs of it

=item ROW - Row on which our first new produced widget pair starts.

=item WIDGETS - Array to keep produced value widgets (Entry, Checkbox)

=item TYPES - Array holding type info strings ('text', 'flag', 'color', 'label')

=item KEYS - Array holding key strings (using for label names)

=item VALOC - Array holding value strings (will be used as defaults on value widgets)

=item RESULT - row-number after our last produced widget

=back


=head2 DESCRIPTION

=cut

sub mask_widget ($$$$$$) {
    my ($mask_frame, $row, $widgets, $types, $keys, $vals) = @_;
    for my $i (0..$#$keys) {
	my ($key, $val) = ($$keys[$i], $$vals[$i]);
	$val="" unless defined $val;
	db_trace("row:$row");
	$mask_frame->Label(-text => "$key")->grid(-row => $row, -column => 0, -sticky => "e");
	if ($$types[$i] eq 'text') {
	    my $entry = $mask_frame->Entry()->grid(-row => $row, -column => 1);
	    $entry->insert(0, $val);
	    $$widgets[$i] = $entry;
	} elsif ($$types[$i] eq 'flag') {
	    my $cb = $mask_frame->Checkbutton()->grid(-row => $row, -column => 1, -sticky => "w");
	    $cb->select if ($val == '1');
	    $$widgets[$i] = $cb;
	} elsif ($$types[$i] eq 'label') {
	    my $label = $mask_frame->Label(-text => "$val")->grid(-row => $row, -column => 1, -sticky => "w");
	    $$widgets[$i] = $label;
	} elsif ($$types[$i] eq 'color') {
	    my $entry = $mask_frame->Entry()->grid(-row => $row, -column => 1);
	    set_color_entry ($entry, $val);

	    $entry->insert(0, $val);
	    $$widgets[$i] = $entry;
	    $mask_frame->Button
		(-text => "$key", -command => sub
		 {
		     my $old_color = get_color_entry ($entry);
		     my $color = $mask_frame->chooseColor(-parent => $mask_frame,
							  -initialcolor => "$old_color");
		     if ($color) {
			 $entry->delete(0, 'end');
			 $entry->insert(0, "$color");
			 set_color_entry ($entry, $color);
		     }
		 } )->grid(-row => $row, -column => 0, -sticky => "ew");

	    # Toggling color preview in Entry widget using MousePress events
	    my ($sub_preview_on, $sub_preview_off);
	    $sub_preview_on = sub {
		set_color_entry ($entry, $entry->get());
		$entry->Tk::bind ('<ButtonPress>', $sub_preview_off);
	    };
	    $sub_preview_off = sub {
		$entry->configure (-fg => $mask_frame->cget('-fg'),
				   -bg => $mask_frame->cget('-bg'));
		$entry->Tk::bind ('<ButtonPress>', $sub_preview_on);
	    };
	    $entry->Tk::bind ('<ButtonPress>', $sub_preview_off);
	}
	$row++;
    }

    $mask_frame->pack(-side => 'top');
    db_trace ("gridSize: " . $mask_frame->gridSize);
    $row;
}

my @cfg__isp_cfg_cache;
sub edit_bt_ok($$$$) {
    my ($frame, $lb, $index, $widgets) = @_;
    my @config_values;

    # copy values from widgets to array @config_values
    foreach my $i (0..$#$widgets) {
	if ($cfg_types[$i] eq 'text') {
	    $config_values[$#config_values+1] = $$widgets[$i]->get;
	} elsif ($cfg_types[$i] eq 'color') {
	    $config_values[$#config_values+1] = $$widgets[$i]->get;
	    set_color_entry ($$widgets[$i], $$widgets[$i]->get);
	} elsif ($cfg_types[$i] eq 'flag') {
	    $config_values[$#config_values+1] = $$widgets[$i]->{'Value'};
	}
    }

    # update (overwrite) global configuration for this ISP
    # (widgets are currently in same order as global ISP config table is
    #  so we can just pass our value array to set_isp_cfg())
    dm::set_isp_cfg (\@config_values);

    # update our configuration cache to reflect change in global configuration made above
    my $isp = $config_values[0];
    foreach my $i (0..$#cfg__isp_cfg_cache) {
	my $r = $cfg__isp_cfg_cache[$i];
	if ($$r[$dm::cfg_isp] eq $isp) {
	    $cfg__isp_cfg_cache[$i] = \@config_values;
	}
    }
}

# TODO: TAB switching order
sub cost_mask_window ($$$$) {
    my ($parent, $matrix, $entries, $balloon) = @_;
    my $labels=$$matrix[0];
    my $balloons=$$matrix[2];
    my $fmts=$$matrix[1];
    my $start_matrix=3;
    my $rows = scalar @$matrix - $start_matrix;
    my $cols = scalar @$labels;
    my $top = $parent->Frame;
    my $table_frame = $top->Frame;
    $table_frame->pack(-side => 'top');
    ## make table columns
    for (my $c=0; $c < $cols; $c++) {
	my @wids;
	# make column label (table head)
	my $label = $table_frame->Label(-text => $$labels[$c])->grid(-row => 0, -column => $c);
	# atach balloon help to table head
	$balloon->attach($label, -balloonmsg => $$balloons[$c]) if $balloon && $$balloons[$c];
	# make column cells
	foreach my $r ($start_matrix..$#$matrix) {
	    if ($$fmts[$c] =~ /^cstring:(\d+)/) {
		my $width=$1;
		my $wid = $table_frame->Entry(-width => $width);
		my $col_matrix= $$matrix[$r];
		# insert data from COL_MATRIX
		$wid->insert(0, $$col_matrix[$c]);
#		$balloon->attach($wid, -balloonmsg => $$balloons[$c]) if $balloon && $$balloons[$c];
		$wid->grid(-row => $r, -column => $c);
		$wids[$#wids+1] = $wid;
	    } elsif (($$fmts[$c] =~ /^checkbox$/)) {
		my $wid = $table_frame->Checkbutton();
		my $col_matrix= $$matrix[$r];
		$wid->select if $$col_matrix[$c];
#		$balloon->attach($wid, -balloonmsg => $$balloons[$c]) if $balloon && $$balloons[$c];
		$wid->grid(-row => $r, -column => $c);
	    }
	}
	$$entries[$#$entries+1]=\@wids;
    }
    my $button_frame = $top->Frame;
    $button_frame->pack(-side => 'bottom');
    foreach my $lab (('Append Row', 'Insert Row', 'Remove Row')) {
	my $wid = $button_frame->Button (-text => $lab, -state => 'disabled');
	$wid->pack (-side => 'left');
    }
    $top;
}
sub cost_mask_window_old ($$$) {
    my ($parent, $matrix, $entries) = @_;
    my $labels=$$matrix[0];
    my $fmts=$$matrix[1];
    my ($rows, $cols) = ($#$matrix-1, $#$labels+1);
    my $top = $parent->Frame;
    my $table_frame = $top->Frame;
    $table_frame->pack(-side => 'top');
    for (my $c=0; $c < $cols; $c++) {
	my $frame=$table_frame->Frame;
	my @wids;
	$frame->Label(-text => $$labels[$c])->pack(-side => 'top');
	for (my $r=2; $r < $rows+2; $r++) {
	    if ($$fmts[$c] =~ /cstring:(\d+)/) {
		my $width=$1;
		my $wid = $frame->Entry(-width => $width);
		my $col_matrix= $$matrix[$r];
		$wid->insert(0, $$col_matrix[$c]);
		$wid->pack(-side => 'bottom',
			   -expand => 1,
			   -fill => 'x');
		$wids[$#wids+1] = $wid;
	    }
	}
	$frame->pack(-expand => 1, -fill => 'x', -side => 'left');
	$$entries[$#$entries+1]=\@wids;
    }
    my $button_frame = $top->Frame;
    $button_frame->pack(-side => 'bottom');
    foreach my $lab (('Append Row', 'Insert Row', 'Remove Row')) {
	my $wid = $button_frame->Button (-text => $lab);
	$wid->pack (-side => 'left');
    }
    $top;
}
## create data table for cost preferece window (cost_mask_window())
## 1st row are labels.  2nd row are data-type-IDs.  In 3rd row starts data.
sub cost_mask_data ($) {
    my ($rate_name) = @_;
    my @labels = ($LOC{'win_rate_date_start'},
		  $LOC{'win_rate_date_end'},
		  $LOC{'win_rate_weekdays'},
		  $LOC{'win_rate_daytime_start'},
		  $LOC{'win_rate_daytime_end'},
		  $LOC{'win_rate_money_per_min'},
		  $LOC{'win_rate_secs_per_unit'},
		  $LOC{'win_rate_money_per_connect'},
		  $LOC{'win_rate_free_linkup'},
		  $LOC{'win_rate_overlay_rate'},
		  );
    my @balloons = ($LOC{'win_rate_date_start.help'},
		    $LOC{'win_rate_date_end.help'},
		    $LOC{'win_rate_weekdays.help'},
		    $LOC{'win_rate_daytime_start.help'},
		    $LOC{'win_rate_daytime_end.help'},
		    $LOC{'win_rate_money_per_min.help'},
		    $LOC{'win_rate_secs_per_unit.help'},
		    $LOC{'win_rate_money_per_connect.help'},
		    $LOC{'win_rate_free_linkup.help'},
		    $LOC{'win_rate_overlay_rate.help'},
		    );
    my @matrix;
    $matrix[$#matrix+1] = \@labels;
    $matrix[$#matrix+1] = ['cstring:10','cstring:10','cstring:10','cstring:10',
			   'cstring:10','cstring:5','cstring:4','cstring:4', 'checkbox', 'checkbox'];
    $matrix[$#matrix+1] = \@balloons;
    my $rate = Dialup_Cost::get_rate ($rate_name);
    foreach my $r (@$rate) {
	my @sub_entries = ("","","","","","","","");
	my $r0 = $$r[0];

	if (ref $$r0[0]) {
	    my $r00 = $$r0[0];
	    $sub_entries[0] = ($$r00[0] == 0) ? "0" : substr (dm::format_ltime ($$r00[0]), 0, 19);
	    $sub_entries[1] = ($$r00[1] == 0) ? "0" : substr (dm::format_ltime ($$r00[1]), 0, 19);
	}
	if (ref $$r0[1]) {
	    my $r01 = $$r0[1];
	    foreach my $wday (@$r01) {
		$sub_entries[2] .= "$wday";
	    }
	}
	if (ref $$r0[2]) {
	    my $r02 = $$r0[2];
	    $sub_entries[3] = dm::format_day_time ($$r02[0]);
	    $sub_entries[4] = dm::format_day_time ($$r02[1]);
	}
	my $r1 = $$r[1];
	$sub_entries[5] = sprintf ("%.2f", ($$r1[0] * 60) / $$r1[1]);
	$sub_entries[6] = $$r1[1];
	$sub_entries[7] = $$r1[3];
	$sub_entries[8] = ($$r1[2] == 0);
	$sub_entries[9] = ($$r1[4] == 2);

	$matrix[$#matrix+1]=\@sub_entries;
    }
    parse_cost_mask_data (\@matrix);
    \@matrix;
}

sub parse_cost_mask_data ($) {
    my ($matrix) = @_;
    my @result;
    my $row_idx=-3;
    foreach my $r (@$matrix) {
	next if $row_idx++ < 0; # skip header and type-definition
	my @res_cond=(0, 0, 0);

	if ($$r[0] ne "") {
	    my $start = ($$r[0] eq "0") ? 0 : dm::parse_ltime ($$r[0]);
	    my $end = ($$r[1] eq "0") ? 0 : dm::parse_ltime ($$r[1]);
	    db_trace ("start: $start end: $end");
	    $res_cond[0] = [ $start, $end ];
	}
	if ($$r[2] ne "") {
	    my $str = $$r[2];
	    my @wdays;
	    while ($str =~ /([0-6])/g) {
		$wdays[$#wdays+1]= $1 * 1;
	    }
	    db_trace ("wdays: @wdays");
	    $res_cond[1] = \@wdays;
	}
	if ($$r[3] ne "") {
	    my $start_time = dm::parse_day_time ($$r[3]);
	    my $end_time = dm::parse_day_time ($$r[4]);
	    db_trace ("start_time: $start_time end_time: $end_time");
	    $res_cond[2] = [ $start_time, $end_time ];
	}

	my $pfg_per_connect = $$r[7] * 1;
	my $secs_per_unit = $$r[6] * 1;
	my $pfg_per_unit = ($$r[5] / 60) * $secs_per_unit;
	my $f1 = $$r[8] == 0;
	my $f2 = ($$r[9] == 1) ? 2 : 1;

	db_trace ("pfg_per_unit: $pfg_per_unit  secs_per_unit: $secs_per_unit  pfg_per_connect: $pfg_per_connect");
	my @res = ( \@res_cond, [ $pfg_per_unit, $secs_per_unit, $f1, $pfg_per_connect, $f2 ] );
	$result[$#result+1]=\@res;
#test#	print STDERR Dialup_Cost::write_list (\@res); 
    }
#test# my %tmp=(xxx => \@result); print STDERR Dialup_Cost::write_data2 (\%tmp); 
    \@result;
}


sub item_edit_bt($$) {
    my ($lb, $index) = @_;
    my @entries;

    my $win = $main_widget->Toplevel;
    my $balloon = $win->Balloon();
    my $isp = $lb->get($index);
    my $isp_rate = dm::get_isp_tarif ($isp);
    $win->title("$APPNAME: cost for rate <$isp_rate>");
    cost_mask_window ($win, cost_mask_data ($isp_rate), \@entries, $balloon)->pack();
};

sub cfg_update_gadgets ($$) {
    my ($idx, $gadgets) = @_;
    my $cfg = $cfg__isp_cfg_cache[$idx];
    for (my $i=0; $i < $dm::cfg_SIZE; $i++) {
#	$$cfg[$i]=$$gadgets[$i]->get();
	if ($cfg_types[$i] eq 'text') {
	    $$gadgets[$i]->delete(0, 'end');
	    $$gadgets[$i]->insert(0, $$cfg[$i]);
	} elsif ($cfg_types[$i] eq 'color') {
	    $$gadgets[$i]->delete(0, 'end');
	    $$gadgets[$i]->insert(0, $$cfg[$i]);
	    set_color_entry ($$gadgets[$i], $$cfg[$i]);
	} elsif ($cfg_types[$i] eq 'flag') {
	    if ($$cfg[$i]) { $$gadgets[$i]->select; } else { $$gadgets[$i]->deselect; }
	}
    }
}

sub cfg_editor_window ($$) {
    my ($xmax, $ymax) = @_;	#(30 * $secs_per_min, 200);
    my $win=$main_widget->Toplevel;
    $win->title("$APPNAME: Config");

    my $frame1 = $win->Frame;
    my $box = $frame1->Listbox(-relief => 'sunken',
			       -width => -1, # Shrink to fit
			       -height => 10,	
			       -selectmode => 'browse',
			       -setgrid => 1);

    my $scroll = $frame1->Scrollbar(-command => ['yview', $box]);
    my $item_entry = $win->Entry();

    my $frame3 = $win->Frame;
    my $item_del_bt = $frame3->Button(-text => 'Delete', -command => sub{item_del_bt($box)});
    my $edit_bt = $frame3->Button(-text => 'Edit Rate', -command => sub{item_edit_bt($box, $box->index('active'))});
    my $item_add_bt = $frame3->Button(-text => 'Add', -command => sub{item_add_bt($box)});
#my $view_bt = $frame3->Button(-text => 'View', -command => sub{view_bt($box)});

    my $frame2 = $win->Frame;
    my $exit_bt = $frame2->Button(-text => 'Close',
				  -command => sub { undef @cfg__isp_cfg_cache; $win->destroy() });
#    my $exit_bt = $frame2->Button(-text => 'Cancel', -command => sub{ $frame2->chooseColor();});
    my $save_bt = $frame2->Button(-text => 'Save',
				  -command => sub{ dm::save_config();
						   undef @cfg__isp_cfg_cache;
						   $win->destroy() });
    foreach (@dm::isps) {
	$box->insert('end', $_);
	my @cfg;
	$cfg__isp_cfg_cache[$#cfg__isp_cfg_cache+1] = \@cfg;
	for (my $i=0; $i < $dm::cfg_SIZE; $i++) {
	    $cfg[$#cfg+1] =  dm::get_isp_cfg ($_, $i);
	}
    }

    $box->configure(-yscrollcommand => ['set', $scroll]);

    $frame1->pack(-fill => 'both', -expand => 1);
    $box->pack(-side => 'left', -fill => 'both', -expand => 1);
    $scroll->pack(-side => 'right', -fill => 'y');
#$item_entry->pack(-fill => 'x');

    {
	my $isp = $box->get(0);
	my $top = $win->Frame;
	mask_widget ($top->Frame, 0, \@entries, \@cfg_types, \@cfg_labels, $dm::isp_cfg_map{$isp});
#exp#	$entries[0]->configure(-invcmd => 'bell', -vcmd => sub { 0; }, -validate => 'focusout');
	my $frame1 = $top->Frame;
	$frame1->Button(-text => 'Cancel', -command => sub{edit_bt_cancel($top)})->pack(-side => 'left');
	$frame1->Button(-text => 'Apply', -command => sub{edit_bt_ok($top, $box, 0, \@entries)})->pack(-side => 'right');
	$frame1->pack(-fill => 'x');
	$top->pack(-expand => 1, -fill => 'both');
    }

    $frame3->pack(-fill => 'x');
#$view_bt->pack(-side => 'bottom');
    $item_add_bt->pack(-side => 'right');
    $item_del_bt->pack(-side => 'left');
    $edit_bt->pack();

    $frame2->pack(-fill => 'x');
    $save_bt->pack(-side => 'right');
    $exit_bt->pack(-side => 'left');

    $box->Tk::bind ('<ButtonRelease>', sub { cfg_update_gadgets ($box->index('active'), \@entries) });
}

sub color_cfg_editor_window ($$) {
    my ($xmax, $ymax) = @_;	#(30 * $secs_per_min, 200);
    my $win=$main_widget->Toplevel;
    $win->title("$APPNAME: Graph Colors");

    my @widgets;
    my @types = ('color', 'color', 'color');
    my @keys = ('Background Color', 'Ruler Color', 'Ruler2 Color');
    my @cfg_keys = ('graph_bgcolor', 'graph_nrcolor', 'graph_ercolor');
    my @vals;
    my @refs;
    my @defaults;
    foreach my $i (0..$#cfg_keys) {
	if (defined $cfg_gui{$cfg_keys[$i]}) {
	    $vals[$i] = $cfg_gui{$cfg_keys[$i]};
	    $refs[$i] = \$cfg_gui{$cfg_keys[$i]};
	    $defaults[$i] = $cfg_gui_default{$cfg_keys[$i]};
	}
    }
    my $top = $win->Frame;
    my $mask_frame = $top->Frame;
    mask_widget ($mask_frame, 0, \@widgets, \@types, \@keys, \@vals);
    $mask_frame->pack(-expand => 1, -fill => 'both');

    my $frame1 = $top->Frame;
    $frame1->Button(-text => 'Cancel', -command => sub { $win->destroy(); })->pack(-side => 'left' );
    $frame1->Button(-text => 'Apply',
		    -command => sub
		    { foreach my $i (0...$#refs) {
			if ($types[$i] eq 'color' or $types[$i] eq 'text') {
			    my $ref = $refs[$i]; 
			    $$ref = $widgets[$i]->get();
			    if ($types[$i] eq 'color') {
				set_color_entry ($widgets[$i], $widgets[$i]->get());
			    }
			}
		    }
		      $win->destroy ();
		    })->pack(-side => 'right');
    $frame1->Button(-text => 'Default',
		    -command => sub
		    { foreach my $i (0..$#cfg_keys) {
			my $ref = $refs[$i];
			my $val = $defaults[$i];
			my $wid = $widgets[$i];
			#$$ref = $val;
			if ($types[$i] eq 'color' or $types[$i] eq 'text') {
			    $wid->delete(0, 'end');
			    $wid->insert(0, "$val");
			    if ($types[$i] eq 'color') {
				set_color_entry ($wid, $val);
			    }
			}
		    }
		  })->pack();
    $frame1->pack(-fill => 'x');
    $top->pack(-expand => 1, -fill => 'both');
}

########################################################################################
sub read_config ($) {
    my ($file) =@_;
    if (open IN, ("$file")) {
	while (<IN>) {
	    if (/^\<([a-z]+) /) {
		my $tag = $1; 
		my @result;
		while (m/\b([a-z_]+)\=["']([^\"\']*)['"]/g) {
		    my ($key, $val) = ($1, dm::unescape_string ($2));
		    if ($tag eq "gui") {
			$cfg_gui{"$key"} = $val;
		    }
		}
	    }
	}
	close IN;
	1;
    } else {
	0;
    }
}

sub write_config ($) {
    my ($file) =@_;
    if (open OUT, (">$file")) {
	my $line="";
	my $count=0;
	while (my ($key, $val) = each (%cfg_gui)) {
	    if ("$cfg_gui_default{$key}" ne $val) {
		$line .= "$key='" . dm::escape_string ($val) . "' ";
		db_trace ("key=<$key> val=<$val> count=<$count>");
	    }
	}
	if ($line) {
	    print OUT '<gui ' . $line . "/>\n";
	}
	close OUT;
	1;
    } else {
	0;
    }
}


##--- Main
read_config((-e $cfg_file_usr) ? $cfg_file_usr : $cfg_file);
make_gui_mainwindow();
MainLoop;
