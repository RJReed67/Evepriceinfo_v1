#!/bin/perl

use strict;
use warnings;
use POE;
use POE::Component::IRC::State;
use POE::Component::IRC::Plugin::BotCommand;
use POE::Component::IRC::Plugin::Connector;
use DBI;
use Locale::Currency::Format;
use XML::LibXML;
use LWP::Simple;
use LWP::UserAgent;
use JSON;
use Time::HiRes qw(time);
use DateTime;
use DateTime::Duration;
use DateTime::Format::MySQL;
 
currency_set('USD','#,###.## ISK',FMT_COMMON);

my $twitch_user = "evepriceinfo";
my $twitch_pwd = "oAuth token goes here";
my $twitch_svr = $twitch_user.".jtvirc.com";
my $twitch_port = "6667";
my $debug = 0;

my $tw_following = "https://api.twitch.tv/kraken/streams/followed";
my $tw_pwd = "oAuth token goes here";

my $interval = 900;
 
my $dbh = DBI->connect("DBI:mysql:database=EvePriceInfo;host=localhost",
                         "DBUsername", "DBPassword",
                         {'RaiseError' => 1});
 
my @channels = ('#ChannelName');
my $irc = POE::Component::IRC::State->spawn(
        Nick   => $twitch_user,
        Server => $twitch_svr,
        Port => $twitch_port,
        Username => $twitch_user,
        Password => $twitch_pwd,
        Debug => $debug,
);
 
POE::Session->create(
        package_states => [
                main => [ qw(_start lag_o_meter tick token_time irc_001 irc_352 irc_botcmd_news irc_botcmd_setnews irc_botcmd_token irc_botcmd_add irc_botcmd_take irc_botcmd_overkill irc_botcmd_server irc_botcmd_evepriceinfo irc_botcmd_pc irc_botcmd_rpc irc_botcmd_pca irc_botcmd_hpc irc_botcmd_plex irc_botcmd_cliff irc_botcmd_reqs irc_botcmd_zkb irc_botcmd_roid irc_botcmd_yield irc_botcmd_yomin irc_botcmd_chart irc_botcmd_skills irc_botcmd_cinfo irc_botcmd_cohh irc_botcmd_zao irc_botcmd_ice irc_botcmd_eveinfo) ],
        ],
);
 
$poe_kernel->run();
 
sub _start {
     my ($kernel, $heap) = @_[KERNEL ,HEAP];
     $heap->{connector} = POE::Component::IRC::Plugin::Connector->new();
     $heap->{next_alarm_time} = int(time()) + $interval;
     $kernel->alarm(tick => $heap->{next_alarm_time});
     $irc->plugin_add('Connector' => $heap->{connector} );
     $kernel->delay( 'lag_o_meter' => 60 );
     $irc->plugin_add('BotCommand', POE::Component::IRC::Plugin::BotCommand->new(
        Addressed => 0,
        Prefix => '!',
        Method => 'privmsg',
        Ignore_unknown => 1,
        Commands => {
                add => 'Gives a user tokens. (Mod Only) Arg: # of tokens to give',
                chart => 'Gives a link to an EVE Skills Chart.',
                cinfo => 'Gives info on a Corporation. Arg: CorpName',
                cliff => 'The EVE learning curve',
                cohh => 'Gives a link to the Cohhilition twitch stream', 
                eveinfo => 'Gives a link to a description of EVE Online',
                evepriceinfo => 'Gives info on this bot',
                hpc => 'Checks the price of an item at all 5 market hubs. Arg: ItemName',
                ice => 'Gives the amounts of Ice Products from refining ice (at perfect refine level). Args: IceType',
                news => 'Latest news from the world of Rushlock.',
                overkill => 'Says Maxim 37',
                plex => 'Gives the price of PLEX. Args: Hub or SystemName or ?',
                pc => 'Checks item price. Args: SystemName ItemName',
                pca => 'Checks 24 hour average price with volume. Args: SystemName ItemName',
                reqs => 'Gives a link to the game system requirements',
                roid => 'Gives link to asteroid types by region',
                rpc => 'Checks item price in a Region. Args: RegionName,ItemName',
                setnews => 'Sets the news for channel. (Mod Only) Arg: News',
                server => 'Gives info on Eve Online Server Status',
                skills => 'Gives a link to a description of the various skills.',
                take => 'Takes tokens from a user. (Mod Only) Arg: # of tokens to take.',
                token => 'Tells the number of tokens a user has.',
                yield => 'Gives the amounts of minerals from processing (at perfect refine level). Args: RefineItem',
                yomin => 'Gives information about Yomin Dranoel',
                zao => 'Gives a link to lokoforloki twitch stream',
                zkb => 'Gives the zkillboard info on a character',
        },
     ));
     $irc->yield(register => qw(all));
     $irc->yield(connect => { } );
     return;
}

sub tick {
     my($kernel,$heap) = @_[KERNEL,HEAP];
     $heap->{next_alarm_time}=int(time())+$interval;
     $kernel->alarm(tick => $heap->{next_alarm_time});
     print time()." timer!\n" if $debug==1;
     if (&tw_stream_online) {
          &token_time("\#ChannelName");
     } else {
          
     }
     return;
}

sub token_time {
     my $where = $_[0];
     $irc->yield(who => "$where");
     return;
}

sub irc_352 {
     my $user = (split / /,$_[ARG1])[1];
     my $sth = $dbh->prepare('SELECT * FROM followers WHERE TwitchID LIKE ?');
     $sth->execute($user);
     my $ref = $sth->fetchrow_hashref();
     if (!$ref) {
          $sth = $dbh->prepare('INSERT INTO followers SET TwitchID = ?, Tokens = 0');
          $sth->execute($user);
     } else {
          my $dt1 = DateTime::Format::MySQL->parse_datetime( $ref->{'TTL'} );
          my $dt2 = DateTime->now(time_zone=>'local');
          my $mins = ($dt2 - $dt1)->minutes;
          my $secs = ($dt2 - $dt1)->seconds;
          my $duration = ($mins * 60) + $secs;
          if ($duration > ($interval - 10) && $duration < ($interval + 10)) {
               my $cur_tokens = $ref->{'Tokens'};
               $sth = $dbh->prepare('UPDATE followers SET Tokens = ?, TTL = NULL WHERE TwitchID like ?');
               $cur_tokens=$cur_tokens+1;
               $sth->execute($cur_tokens,$user);
          } else {
               $sth = $dbh->prepare('UPDATE followers SET TTL = NULL WHERE TwitchID like ?');
               $sth->execute($user);
          }
     }
     return;
}
 
sub irc_001 {
     $irc->yield(join => $_) for @channels;
     $irc->yield(privmsg => $_, '/color blue') for @channels;
     return;
}

sub lag_o_meter {
     my($kernel,$heap) = @_[KERNEL,HEAP];
     print 'Time: '.time().' Lag: '.$heap->{connector}->lag()."\n" if $debug==1;
     $kernel->delay( 'lag_o_meter' => 60 );
     return;
}

sub irc_botcmd_add {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     my ($change, $user) = split(' ', $arg, 2);
     if ($irc->is_channel_operator($where,$nick)) {
          my $sth = $dbh->prepare('SELECT * FROM followers WHERE TwitchID LIKE ?');
          $sth->execute($user);
          my $ref = $sth->fetchrow_hashref();
          if (!$ref) {
               $irc->yield(privmsg => $where, "User $user not found in token table.");
          } else {
               my $cur_tokens = $ref->{'Tokens'};
               $sth = $dbh->prepare('UPDATE followers SET Tokens = ?, TTL = ?  WHERE TwitchID like ?');
               $cur_tokens = $cur_tokens + $change;
               $sth->execute($cur_tokens,$ref->{'TTL'},$user);
               $irc->yield(privmsg => $where, "$change tokens added to $user\'s balance.");
          }
     }
     return;
}

sub irc_botcmd_take {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     my ($change, $user) = split(' ', $arg, 2);
     if ($irc->is_channel_operator($where,$nick)) {
          my $sth = $dbh->prepare('SELECT * FROM followers WHERE TwitchID LIKE ?');
          $sth->execute($user);
          my $ref = $sth->fetchrow_hashref();
          if (!$ref) {
               $irc->yield(privmsg => $where, "User $user not found in token table.");
          } else {
               my $cur_tokens = $ref->{'Tokens'};
               $sth = $dbh->prepare('UPDATE followers SET Tokens = ?, TTL = ? WHERE TwitchID like ?');
               $cur_tokens = $cur_tokens - $change;
               $sth->execute($cur_tokens,$ref->{'TTL'},$user);
               $irc->yield(privmsg => $where, "$change tokens taken from $user\'s balance.");
          }
     }

     return;
}

sub irc_botcmd_token {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     if ($arg) {
          if ($irc->is_channel_operator($where,$nick) && $arg ne "?") {
               my $sth = $dbh->prepare('SELECT * FROM followers WHERE TwitchID LIKE ?');
               $sth->execute($arg);
               my $ref = $sth->fetchrow_hashref();
               if (!$ref) {
                    $irc->yield(privmsg => $where, "User $arg not found in token table.");
               } else {
                    $irc->yield(privmsg => $where, "$arg has $ref->{'Tokens'} tokens.");
               }
          } else {
               if (&tw_stream_online) {
                    $irc->yield(privmsg => $where, "Viewers will earn 1 token every 15 minutes in channel while live! Giveaways will require, but not take, tokens to enter. Check your token balance after the cast with !token");
               } else {
                    $irc->yield(privmsg => $where, "Viewers will earn 1 token every 15 minutes in channel while live! Giveaways will require, but not take, tokens to enter.");
               }
          }
     } else {
          if (!&tw_stream_online) {
               my $sth = $dbh->prepare('SELECT * FROM followers WHERE TwitchID LIKE ?');
               $sth->execute($nick);
               my $ref = $sth->fetchrow_hashref();
               if (!$ref) {
                    $irc->yield(privmsg => $where, "User $nick not found in token table.");
               } else {
                    $irc->yield(privmsg => $where, "$nick has $ref->{'Tokens'} tokens.");
               }
          }
     }
     return;
}
 
sub irc_botcmd_setnews {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     if ($irc->is_channel_operator($where,$nick)) {
          open(NEWSFILE,">news.txt");
          $arg =~ s/^\!\w//;
          print NEWSFILE $arg;
          close(NEWSFILE);
          $irc->yield(privmsg => $where, "News Set!");
     }  
     return;
}

sub irc_botcmd_news {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     open(NEWSFILE,"news.txt");
     while (<NEWSFILE>) {
          $irc->yield(privmsg => $where, "News: $_");
     }
     close(NEWSFILE);
     return;
}
 
sub irc_botcmd_overkill {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     $irc->yield(privmsg => $where, 'Maxim #37: There is no "Overkill", there is only "Open Fire", and "I need to reload"');
     return;
}
 
sub irc_botcmd_skills {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     $irc->yield(privmsg => $where, 'EVE Skill Descriptions: http://games.chruker.dk/eve_online/basic_skills.php');
     return;
}
 
sub irc_botcmd_chart {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     $irc->yield(privmsg => $where, 'EVE Skill Chart: http://swiftandbitter.com/eve/wtd/');
     return;
}
 
sub irc_botcmd_eveinfo {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     $irc->yield(privmsg => $where, 'EVE Online Description: http://www.destructoid.com/eve-the-unforgiving-a-basic-understanding-of-ccp-s-masterpiece-127961.phtml');
     return;
}
 
sub irc_botcmd_cliff {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     $irc->yield(privmsg => $where, 'EVE learning curve: http://dedricmauriac.files.wordpress.com/2010/06/eve-learning-curve.jpg');
     return;
}
 
sub irc_botcmd_roid {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     $irc->yield(privmsg => $where, 'EVE asteroid type distribution: http://www.eve-wiki.net/images/0/03/Glow_roid_grid.jpg');
     return;
}
 
sub irc_botcmd_cohh {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     $irc->yield(privmsg => $where, 'Check out the Cohhilition at www.twitch.tv/cohhcarnage');
     return;
}
 
sub irc_botcmd_zao {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     $irc->yield(privmsg => $where, 'Great channel for new or solo PVP interest! http://twitch.tv/lokoforloki');
     return;
}
 
sub irc_botcmd_yield {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     my @mins=("Tritanium","Pyerite","Mexallon","Isogen","Nocxium","Zydrine","Megacyte","Morphite");
     my $sth = $dbh->prepare('SELECT * FROM refineInfo WHERE refineItem LIKE ?');
     $sth->execute($arg);
     my $ref = $sth->fetchrow_hashref();
     if (!$ref) {
        $irc->yield(privmsg => $where, "$arg is not a valid Item.");
        return -1;
     }
     my %items = %$ref;
     my $msg = "$arg yields: ";
     foreach my $mineral (@mins) {
          my $amt = $ref->{$mineral};
          if ($amt > 0) {
               $msg = $msg.$mineral.":".$amt." ";
          }
     }
     $msg = $msg."for every ".$ref->{'batchsize'}." units refined.";
     $sth->finish;
     $irc->yield(privmsg => $where, $msg);
     return;
}
 
sub irc_botcmd_ice {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     my @mins=("Heavy Water","Helium Isotopes","Hydrogen Isotopes","Nitrogen Isotopes","Oxygen Isotopes","Liquid Ozone","Strontium Calthrates");
     my $sth = $dbh->prepare('SELECT * FROM icerefine WHERE icetype LIKE ?');
     $sth->execute($arg);
     my $ref = $sth->fetchrow_hashref();
     if (!$ref) {
        $irc->yield(privmsg => $where, "$arg is not a valid Ice Type.");
        return -1;
     }
     my %items = %$ref;
     my $msg = "$arg yields: ";
     foreach my $mineral (@mins) {
          my $amt = $ref->{$mineral};
          if ($amt > 0) {
               $msg = $msg.$mineral.":".$amt." ";
          }
     }
     $msg = $msg."for every ".$ref->{'RefineSize'}." unit refined.";
     $sth->finish;
     $irc->yield(privmsg => $where, $msg);
     return;
}
 
sub irc_botcmd_reqs {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     $irc->yield(privmsg => $where, 'EVE system requirements: http://community.eveonline.com/support/knowledge-base/article.aspx?articleId=124');
     return;
}
 
sub irc_botcmd_evepriceinfo {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     $irc->yield(privmsg => $where, 'Evepriceinfo written by RJReed67. All market data is gathered from eve-central website. Kill data gathered from zkillboard. Please report any problems or spelling errors to twitch name RJReed67.');
     return;
}
 
sub irc_botcmd_yomin {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     $irc->yield(privmsg => $where, 'Yomin Dranoel, one evil bastard.');
     return;
}

sub irc_botcmd_plex {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     if (not defined $arg) {
          $irc->yield(privmsg => $where, "Query must have in a SystemName or the word Hub. (e.g. !plex Hub)");
          return;
     }
     if ($arg eq "?") {
          $irc->yield(privmsg => $where, "PLEX is an in-game item, that can be purchased with real money or in-game currency called ISK. PLEX gives you an extra 30 days of game time on your Eve Online account.");
          return;
     }
     $arg = lc($arg);
     if ($arg eq "hub") {
          my %hubs = ("Jita",30000142,"Hek",30002053,"Rens",30002510,"Amarr",30002187,"Dodixie",30002659);
          my $price="";
          while ((my $sysname, my $sysid) = each (%hubs)) {
               $price = $price.$sysname.":".currency_format('USD', &GetXMLValue($sysid,29668,"//sell/min"), FMT_COMMON)." ";
          }
          $irc->yield(privmsg => $where, "Market Hub Prices for PLEX - $price");
     } else {
     my $sysid = &SystemLookup($arg,$where);
     if ($sysid == -1) {
          return;
     };
          my $maxprice = &GetXMLValue($sysid,29668,"//sell/min");
          if ($maxprice != 0) {
               $maxprice = currency_format('USD', $maxprice, FMT_COMMON);
               $irc->yield(privmsg => $where, "PLEX is selling for $maxprice in $arg.");
          } else {
               $irc->yield(privmsg => $where, "There is no PLEX for sell in $arg.");
          }
     }
     return;
}

sub irc_botcmd_pc {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     my ($sysname, $itemname) = split(' ', $arg, 2);
     if (not defined $itemname) {
          $irc->yield(privmsg => $where, "Query must be in the form of SystemName and ItemName. (e.g. !pc Rens Punisher)");
          return;
     }
     my $sysid = &SystemLookup($sysname,$where);
     if ($sysid == -1) { return; };
     my $itemid = &ItemLookup($itemname,$where);
     if ($itemid == -1) { return; };
     my $maxprice = &GetXMLValue($sysid,$itemid,"//sell/min");
     if ($maxprice != 0) {
          $maxprice = currency_format('USD', $maxprice, FMT_COMMON);
          $irc->yield(privmsg => $where, "$itemname is selling for $maxprice in $sysname.");
     } else {
          $irc->yield(privmsg => $where, "There is no $itemname for sell in $sysname.");
     }
     return;
}
 
sub irc_botcmd_rpc {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     my ($regname, $itemname) = split(',', $arg, 2);
     if (not defined $itemname) {
          $irc->yield(privmsg => $where, "Query must be in the form of RegionName,ItemName. (e.g. !rpc Lonetrek,Punisher)");
          return;
     }
     my $regid = &RegionLookup($regname,$where);
     if ($regid == -1) { return; };
     my $itemid = &ItemLookup($itemname,$where);
     if ($itemid == -1) { return; };
     my $maxprice = &GetXMLValueReg($regid,$itemid,"//sell/min");
     if ($maxprice != 0) {
          $maxprice = currency_format('USD', $maxprice, FMT_COMMON);
          $irc->yield(privmsg => $where, "$itemname is selling for $maxprice in $regname region.");
     } else {
          $irc->yield(privmsg => $where, "There is no $itemname for sell in $regname region.");
     }
     return;
}
 
sub irc_botcmd_pca {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     my ($sysname, $itemname) = split(' ', $arg, 2);
     if (not defined $itemname) {
          $irc->yield(privmsg => $where, "Query must be in the form of SystemName and ItemName. (e.g. !pca Rens Punisher)");
          return;
     }
     my $sysid = &SystemLookup($sysname,$where);
     if ($sysid == -1) { return; };
     my $itemid = &ItemLookup($itemname,$where);
     if ($itemid == -1) { return; };
     my $avgprice = &GetXMLValue($sysid,$itemid,"//all/avg");
     my $volume = &GetXMLValue($sysid,$itemid,"//all/volume");
     if ($avgprice != 0) {
          $avgprice = currency_format('USD', $avgprice, FMT_COMMON);
          $irc->yield(privmsg => $where, "$itemname has sold $volume units in the past 24 hours, at an average price of $avgprice in $sysname.");
     } else {
          $irc->yield(privmsg => $where, "There is no $itemname for sell in $sysname.");
     }
     return;
}
 
sub irc_botcmd_hpc {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     my %hubs = ("Jita",30000142,"Hek",30002053,"Rens",30002510,"Amarr",30002187,"Dodixie",30002659);
     my $itemid = &ItemLookup($arg,$where);
     if ($itemid == -1) { return; };
     my $price="";
     while ((my $sysname, my $sysid) = each (%hubs)) {
          my $hprice = &GetXMLValue($sysid,$itemid,"//sell/min");
          if ( $hprice > 0) {
               $price = $price.$sysname.":".currency_format('USD', $hprice, FMT_COMMON)." ";
          }
     }
     if ($price ne "") {
          $irc->yield(privmsg => $where, "Market Hub Prices for $arg - $price");
     } else {
          $irc->yield(privmsg => $where, "$arg is not available at any market hub.");
     }
}
 
sub irc_botcmd_server {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $arg) = @_[ARG1, ARG2];
     my $url = get('https://api.eveonline.com/server/ServerStatus.xml.aspx');
     my $parser = new XML::LibXML;
     my $doc = $parser->parse_string($url);
     my $xpath="//result/onlinePlayers/text()";
     my $value = $doc->findnodes($xpath);
     $xpath="//currentTime/text()";
     my $time = $doc->findvalue($xpath);
     $xpath="//result/serverOpen/text()";
     my $online = $doc->findnodes($xpath);
     if ($online =~ /True/) {
          $irc->yield(privmsg => $where, "Server is Online with $value Players. Server Time: $time");
     } else {
          $irc->yield(privmsg => $where, "Server is currently Offline. Server Time: $time");
     }
     return;
}

sub irc_botcmd_zkb {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $charname) = @_[ARG1, ARG2];
     if (not defined $charname) {
          $irc->yield(privmsg => $where, "Query must be in the form of a single character name. (e.g. !zkb Ira Warwick)");
          return;
     }
     my $charid = &CharIDLookup($charname);
     if ($charid == -1) {
          $irc->yield(privmsg => $where, "There is no $charname in the Eve Universe.");
          return;
     };
     &ZkbLookup($charname,$charid,$where);
     return;
}

sub irc_botcmd_cinfo {
     my $nick = (split /!/, $_[ARG0])[0];
     my ($where, $corpname) = @_[ARG1, ARG2];
     if (not defined $corpname) {
          $irc->yield(privmsg => $where, "Query must be in the form of a single corporation name. (e.g. !cinfo The Romantics)");
          return;
     }
     my $corpid = &CharIDLookup($corpname);
     if ($corpid == -1) {
          $irc->yield(privmsg => $where, "There is not a corporation named $corpname in the Eve Universe.");
          return;
     };
     &CorpLookup($corpname,$corpid,$where);
     return;
}

sub CorpLookup {
     my $url = "https://api.eveonline.com/corp/CorporationSheet.xml.aspx?corporationID=$_[1]";
     my $content = get($url);
     if (not defined $content) {
          $irc->yield(privmsg => $_[2], "$_[0] was not found.");
          return;
     }    
     my $parser = new XML::LibXML;
     my $doc = $parser->parse_string($content);
     my $xpath="//ceoName";
     my $ceoname = $doc->findvalue($xpath);
     $xpath="//memberCount";
     my $memcount = $doc->findvalue($xpath);
     $xpath="//stationName";
     my $station = $doc->findvalue($xpath);
     $irc->yield(privmsg => $_[2], "$_[0] - CEO: $ceoname - Members: $memcount - HQ: $station");
     return;
}

sub GetXMLValue {
     my $url = "http://api.eve-central.com/api/marketstat?usesystem=$_[0]&typeid=$_[1]";
     my $parser = new XML::LibXML;
     my $doc = $parser->parse_file("$url");
     my $xpath="//sell/min";
     my $value = $doc->findvalue($_[2]);
     return $value;
}
 
sub GetXMLValueReg {
     my $url = "http://api.eve-central.com/api/marketstat?regionlimit=$_[0]&typeid=$_[1]";
     my $parser = new XML::LibXML;
     my $doc = $parser->parse_file("$url");
     my $xpath="//sell/min";
     my $value = $doc->findvalue($_[2]);
     return $value;
}
 
sub ItemLookup {
     my $sth = $dbh->prepare('SELECT ItemID FROM typeids WHERE ItemName LIKE ?');
     $sth->execute($_[0]);
     my $ref = $sth->fetchrow_hashref();
     if (!$ref) {
        $irc->yield(privmsg => $_[1], "$_[0] is not a valid Item.");
        return -1;
     }
     my $itemid = $ref->{'ItemID'};
     $sth->finish;
     return $itemid;
}
 
sub SystemLookup {
     my $sth = $dbh->prepare('SELECT SystemID FROM systemids WHERE SystemName LIKE ?');
     $sth->execute($_[0]);
     my $ref = $sth->fetchrow_hashref();
     if (!$ref) {
        $irc->yield(privmsg => $_[1], "$_[0] is not a valid System.");
        return -1;
     }
     my $sysid = $ref->{'SystemID'};
     $sth->finish;
     return $sysid;
}
 
sub RegionLookup {
     my $sth = $dbh->prepare('SELECT RegionID FROM regionids WHERE RegionName LIKE ?');
     $sth->execute($_[0]);
     my $ref = $sth->fetchrow_hashref();
     if (!$ref) {
        $irc->yield(privmsg => $_[1], "$_[0] is not a valid Region.");
        return -1;
     }
     my $regid = $ref->{'RegionID'};
     $sth->finish;
     return $regid;
}

sub CharIDLookup {
     my $url = "https://api.eveonline.com/eve/CharacterID.xml.aspx?names=$_[0]";
     my $content = get($url);
     my $parser = new XML::LibXML;
     my $doc = $parser->parse_string($content);
     my $xpath="//result/rowset/row/\@characterID";
     my $value = $doc->findvalue($xpath);
     if ($value == 0) {
          return -1;
     } else {
          return $value;
     }
}

sub ZkbLookup {
     my $url = "https://zkillboard.com/api/stats/characterID/$_[1]/xml";
     my $content = get($url);
     if (not defined $content) {
          $irc->yield(privmsg => $_[2], "$_[0] was not found at zKillboard.com.");
          return;
     }    
     my $parser = new XML::LibXML;
     my $doc = $parser->parse_string($content);
     my $xpath="//row[\@type='count']/\@destroyed";
     my $shipdest = $doc->findvalue($xpath);
     $xpath="//row[\@type='count']/\@lost";
     my $shiplost = $doc->findvalue($xpath);
     $xpath="//row[\@type='isk']/\@destroyed";
     my $iskdest = $doc->findvalue($xpath);
     $xpath="//row[\@type='isk']/\@lost";
     my $isklost = $doc->findvalue($xpath);
     my $msg = "$_[0] has ";
     if ($shipdest == 0) {
          $msg = $msg." not destroyed any ships, ";
     } elsif ($shipdest == 1) {
          $msg = $msg." destroyed $shipdest ship, worth ".currency_format('USD', $iskdest, FMT_COMMON)." ";
     } else {
          $msg = $msg." destroyed $shipdest ships, worth ".currency_format('USD', $iskdest, FMT_COMMON)." ";
     }
     $msg = $msg."and ";
     if ($shiplost == 0) {
          $msg = $msg." has not lost any ships.";
     } elsif ($shiplost == 1) {
          $msg = $msg." lost $shiplost ship, worth ".currency_format('USD', $iskdest, FMT_COMMON).".";
     } else {
          $msg = $msg." lost $shiplost ships, worth ".currency_format('USD', $isklost, FMT_COMMON).".";
     }
     $irc->yield(privmsg => $_[2],$msg);
     return;
}

sub tw_stream_online {
     my $ua = LWP::UserAgent->new;
     my $live = $ua->get($tw_following,"Accept"=>"application/vnd.twitchtv.v2+json","Authorization"=>$tw_pwd);
     my $decode = decode_json( $live->content );
     my @streams = @{$decode->{'streams'}};
     my $id = $streams[0]->{'_id'};
     return 1 if $id;
     return 0;
}
