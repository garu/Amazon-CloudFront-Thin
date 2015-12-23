### Amazon::CloudFront::Thin ###

This module provides a thin, lightweight, low-level Amazon CloudFront
client for Perl 5.

It is designed for only ONE purpose: send a request and get a response,
and it tries to conform with Amazon's own API.

#### Basic Usage

```perl
    use Amazon::CloudFront::Thin;

    my $cloudfront = Amazon::CloudFront::Thin->new({
        aws_access_key_id     => $key_id,
        aws_secret_access_key => $access_key,
        distribution_id       => 'my-cloudfront-distribution',
    });

    my $res = $cloudfront->create_invalidation(
       '/path/to/some/object.jpg',
       '/path/to/another/object.bin',
    );
```

For more information, please refer to the
[Amazon::CloudFront::Thin's complete documentation](https://metacpan.org/pod/Amazon::CloudFront::Thin).

#### Installation

    cpanm Amazon::CloudFront::Thin

#### Unicode

Amazon appears to reference filenames containing non ASCII charachters by URL Encoding the filenames. The following code takes a path such as events/الابحاث which contains both a slash to indicate a directory boundary and a non-ascii filename and creates an invalidation: 

```
  use Amazon::CloudFront::Thin;
  use URL::Encode qw(url_encode_utf8);

  my $cloudfront = Amazon::CloudFront::Thin::->new({
    aws_access_key_id     => $aws_access_key_id,
    aws_secret_access_key => $aws_secret_access_key,
    distribution_id       => $distribution_id,
  });

  my $encoded_filename = url_encode_utf8($path);
  $encoded_filename    =~ s!%2F!/!g;  # "/" will be encoded as %2F, but we want it as "/"
  $cloudfront->create_invalidation( '/' . $encoded_filename );
```
