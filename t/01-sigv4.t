use strict;
use warnings;
use Test::More tests => 4;
use URI           ();
use HTTP::Headers ();
use Digest::SHA   ();

use Amazon::CloudFront::Thin;

my $url = URI->new('https://cloudfront.amazonaws.com/');

my @paths = qw(
    /blog/some/document.pdf
    /images/*
);
my $time = 1438972482; # <-- time()

my $content = Amazon::CloudFront::Thin::_create_xml_payload(\@paths, $time);

is(
    $content,
    '<?xml version="1.0" encoding="UTF-8"?><InvalidationBatch xmlns="http://cloudfront.amazonaws.com/doc/2015-04-17/"><Paths><Quantity>2</Quantity><Items><Path><![CDATA[/blog/some/document.pdf]]></Path><Path><![CDATA[/images/*]]></Path></Items></Paths><CallerReference>1438972482</CallerReference></InvalidationBatch>',
    'payload created successfully'
);

my $headers = HTTP::Headers->new(
    'Content-Length' => 312,
    'Content-Type'   => 'text/xml',
    'Host'           => $url->host,
);
$headers->date($time);

my $canonical_request = Amazon::CloudFront::Thin::_create_canonical_request(
    $url, $headers, $content
);

my $expected = <<'EOEXPECTED';
POST
/

content-length:312
content-type:text/xml
date:Fri, 07 Aug 2015 18:34:42 GMT
host:cloudfront.amazonaws.com

content-length;content-type;date;host
64b09f3f2181c5d78ac37f12611e5a9ca0269a2da1dd515e8828e6165a8da029
EOEXPECTED
chomp $expected;

is $canonical_request, $expected, 'canonical request created successfully';

is(
    Digest::SHA::sha256_hex($canonical_request),
    '96e95f0294536f0d93e8149a8d223fabd87057c4efc5bddbb53083c5c654a831',
    'sha256 matches canonical request'
);

my $string_to_sign = Amazon::CloudFront::Thin::_create_string_to_sign(
    $headers, $canonical_request
);

my @date = (localtime $time)[5,4,3];
$date[0] += 1900;
$date[1] += 1;
is(
    Amazon::CloudFront::Thin::_create_signature(
        'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        $string_to_sign,
        sprintf('%d%02d%02d', @date)
    ),
   '566774087f000ad632750e2f87b8cb69720abd8d43e82daa8e47e99fe22844e6',
   'v4 signature created successfully'
);


