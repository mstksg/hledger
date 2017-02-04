## balance
Show accounts and their balances. Alias: bal.

`--change`
: show balance change in each period (default)

`--cumulative`
: show balance change accumulated across periods (in multicolumn reports)

`-H --historical`
: show historical ending balance in each period (includes postings before report start date)

`--tree`
: show accounts as a tree; amounts include subaccounts (default in simple reports)

`--flat`
: show accounts as a list; amounts exclude subaccounts except when account is depth-clipped (default in multicolumn reports)

`-A --average`
: show a row average column (in multicolumn mode)

`-T --row-total`
: show a row total column (in multicolumn mode)

`-N --no-total`
: don't show the final total row

`--drop=N`
: omit N leading account name parts (in flat mode)

`--no-elide`
: don't squash boring parent accounts (in tree mode)

`--format=LINEFORMAT`
: in single-column balance reports: use this custom line format

`-O FMT --output-format=FMT     `
: select the output format. Supported formats:
txt, csv.

`-o FILE --output-file=FILE`
: write output to FILE.  A file extension matching one of the above formats selects that format.

The balance command displays accounts and balances.
It is hledger's most featureful and most useful command.

```shell
$ hledger balance
                 $-1  assets
                  $1    bank:saving
                 $-2    cash
                  $2  expenses
                  $1    food
                  $1    supplies
                 $-2  income
                 $-1    gifts
                 $-1    salary
                  $1  liabilities:debts
--------------------
                   0
```

More precisely, the balance command shows the *change* to each account's balance caused by all (matched) postings.
In the common case where you do not filter by date and your journal sets the correct opening balances, this is the same as the account's ending balance.

By default, accounts are displayed hierarchically, with subaccounts
indented below their parent.
"Boring" accounts, which contain a single interesting
subaccount and no balance of their own, are elided into the following
line for more compact output. (Use `--no-elide` to prevent this.)

Each account's balance is the "inclusive" balance - it includes the
balances of any subaccounts.


Accounts which have zero balance (and no non-zero subaccounts) are
omitted. Use `-E/--empty` to show them.

A final total is displayed by default; use `-N/--no-total` to suppress it:

```shell
$ hledger balance -p 2008/6 expenses --no-total
                  $2  expenses
                  $1    food
                  $1    supplies
```

### Flat mode

To see a flat list of full account names instead of the default hierarchical display, use `--flat`.
In this mode, accounts (unless depth-clipped) show their "exclusive" balance, excluding any subaccount balances.
In this mode, you can also use `--drop N` to omit the first few account name components.

```shell
$ hledger balance -p 2008/6 expenses -N --flat --drop 1
                  $1  food
                  $1  supplies
```

### Depth limited balance reports

With `--depth N`, balance shows accounts only to the specified depth.
This is very useful to show a complex charts of accounts in less detail.
In flat mode, balances from accounts below the depth limit will be shown as part of a parent account at the depth limit.

```shell
$ hledger balance -N --depth 1
                 $-1  assets
                  $2  expenses
                 $-2  income
                  $1  liabilities
```

<!-- $ for y in 2006 2007 2008 2009 2010; do echo; echo $y; hledger -f $y.journal balance ^expenses --depth 2; done -->

### Multicolumn balance reports

With a [reporting interval](#reporting-interval), multiple balance
columns will be shown, one for each report period.
There are three types of multi-column balance report, showing different information:

1. By default: each column shows the sum of postings in that period,
ie the account's change of balance in that period. This is useful eg
for a monthly income statement:
<!--
multi-column income statement: 

   $ hledger balance ^income ^expense -p 'monthly this year' --depth 3

or cashflow statement:

   $ hledger balance ^assets ^liabilities 'not:(receivable|payable)' -p 'weekly this month'
-->

    ```shell
    $ hledger balance --quarterly income expenses -E
    Balance changes in 2008:

                       ||  2008q1  2008q2  2008q3  2008q4 
    ===================++=================================
     expenses:food     ||       0      $1       0       0 
     expenses:supplies ||       0      $1       0       0 
     income:gifts      ||       0     $-1       0       0 
     income:salary     ||     $-1       0       0       0 
    -------------------++---------------------------------
                       ||     $-1      $1       0       0 

    ```

2. With `--cumulative`: each column shows the ending balance for that
period, accumulating the changes across periods, starting from 0 at
the report start date:

    ```shell
    $ hledger balance --quarterly income expenses -E --cumulative
    Ending balances (cumulative) in 2008:

                       ||  2008/03/31  2008/06/30  2008/09/30  2008/12/31 
    ===================++=================================================
     expenses:food     ||           0          $1          $1          $1 
     expenses:supplies ||           0          $1          $1          $1 
     income:gifts      ||           0         $-1         $-1         $-1 
     income:salary     ||         $-1         $-1         $-1         $-1 
    -------------------++-------------------------------------------------
                       ||         $-1           0           0           0 

    ```

3. With `--historical/-H`: each column shows the actual historical
ending balance for that period, accumulating the changes across
periods, starting from the actual balance at the report start date.
This is useful eg for a multi-period balance sheet, and when
you are showing only the data after a certain start date:

    ```shell
    $ hledger balance ^assets ^liabilities --quarterly --historical --begin 2008/4/1
    Ending balances (historical) in 2008/04/01-2008/12/31:

                          ||  2008/06/30  2008/09/30  2008/12/31 
    ======================++=====================================
     assets:bank:checking ||          $1          $1           0 
     assets:bank:saving   ||          $1          $1          $1 
     assets:cash          ||         $-2         $-2         $-2 
     liabilities:debts    ||           0           0          $1 
    ----------------------++-------------------------------------
                          ||           0           0           0 

    ```

Multi-column balance reports display accounts in flat mode by default;
to see the hierarchy, use `--tree`.

With a reporting interval (like `--quarterly` above), the report
start/end dates will be adjusted if necessary so that they encompass
the displayed report periods. This is so that the first and last
periods will be "full" and comparable to the others.

The `-E/--empty` flag does two things in multicolumn balance reports:
first, the report will show all columns within the specified report
period (without -E, leading and trailing columns with all zeroes are
not shown). Second, all accounts which existed at the report start
date will be considered, not just the ones with activity during the
report period (use -E to include low-activity accounts which would
otherwise would be omitted).

The `-T/--row-total` flag adds an additional column showing the total
for each row.

The `-A/--average` flag adds a column showing the average value in
each row.

Here's an example of all three:

```shell
$ hledger balance -Q income expenses --tree -ETA
Balance changes in 2008:

            ||  2008q1  2008q2  2008q3  2008q4    Total  Average 
============++===================================================
 expenses   ||       0      $2       0       0       $2       $1 
   food     ||       0      $1       0       0       $1        0 
   supplies ||       0      $1       0       0       $1        0 
 income     ||     $-1     $-1       0       0      $-2      $-1 
   gifts    ||       0     $-1       0       0      $-1        0 
   salary   ||     $-1       0       0       0      $-1        0 
------------++---------------------------------------------------
            ||     $-1      $1       0       0        0        0 

# Average is rounded to the dollar here since all journal amounts are

```

### Market value

The `-V/--value` flag converts the reported amounts to their market value
on the report end date, using the most recent applicable market prices,
when known.
Specifically, when there is a [market price](journal.html#market-prices) (P directive)
for the amount's commodity, dated on or before the
[report end date](hledger.html#report-start-end-date) (see hledger -> Report start & end date), 
the amount will be converted to the price's commodity.
If multiple applicable prices are defined, the latest-dated one is used
(and if dates are equal, the one last parsed).

For example:

```journal
# one euro is worth this many dollars from nov 1
P 2016/11/01 € $1.10

# purchase some euros on nov 3
2016/11/3
    assets:euros        €100
    assets:checking

# the euro is worth fewer dollars by dec 21
P 2016/12/21 € $1.03
```
How many euros do I have ?
```
$ hledger -f t.j bal euros
                €100  assets:euros
```
What are they worth on nov 3 ? (no report end date specified, defaults to the last date in the journal)
```
$ hledger -f t.j bal euros -V
             $110.00  assets:euros
```
What are they worth on dec 21 ?
```
$ hledger -f t.j bal euros -V -e 2016/12/21
             $103.00  assets:euros
```

Currently, hledger's -V only uses market prices recorded with P directives,
not [transaction prices](journal.html#transaction-prices) (unlike Ledger).

Using -B and -V together is allowed.

### Custom balance output

In simple (non-multi-column) balance reports, you can customise the
output with `--format FMT`:

```shell
$ hledger balance --format "%20(account) %12(total)"
              assets          $-1
         bank:saving           $1
                cash          $-2
            expenses           $2
                food           $1
            supplies           $1
              income          $-2
               gifts          $-1
              salary          $-1
   liabilities:debts           $1
---------------------------------
                                0
```

The FMT format string (plus a newline) specifies the formatting
applied to each account/balance pair. It may contain any suitable
text, with data fields interpolated like so:

`%[MIN][.MAX](FIELDNAME)`

- MIN pads with spaces to at least this width (optional)
- MAX truncates at this width (optional)
- FIELDNAME must be enclosed in parentheses, and can be one of:

    - `depth_spacer` - a number of spaces equal to the account's depth, or if MIN is specified, MIN * depth spaces.
    - `account`      - the account's name
    - `total`        - the account's balance/posted total, right justified

Also, FMT can begin with an optional prefix to control how
multi-commodity amounts are rendered:

- `%_` - render on multiple lines, bottom-aligned (the default)
- `%^` - render on multiple lines, top-aligned
- `%,` - render on one line, comma-separated

There are some quirks. Eg in one-line mode, `%(depth_spacer)` has no
effect, instead `%(account)` has indentation built in.
<!-- XXX retest:
Consistent column widths are not well enforced, causing ragged edges unless you set suitable widths.
Beware of specifying a maximum width; it will clip account names and amounts that are too wide, with no visible indication.
-->
Experimentation may be needed to get pleasing results.

Some example formats:

- `%(total)`         - the account's total
- `%-20.20(account)` - the account's name, left justified, padded to 20 characters and clipped at 20 characters
- `%,%-50(account)  %25(total)` - account name padded to 50 characters, total padded to 20 characters, with multiple commodities rendered on one line
- `%20(total)  %2(depth_spacer)%-(account)` - the default format for the single-column balance report

### Output destination

The balance, print, register and stats commands can write their output to a
destination other than the console. This is controlled by the
`-o/--output-file` option.

```shell
$ hledger balance -o -     # write to stdout (the default)
$ hledger balance -o FILE  # write to FILE
```

### CSV output

The balance, print and register commands can write their output as
CSV. This is useful for exporting data to other applications, eg to
make charts in a spreadsheet. This is controlled by the
`-O/--output-format` option, or by specifying a `.csv` file extension
with `-o/--output-file`.

```shell
$ hledger balance -O csv       # write CSV to stdout
$ hledger balance -o FILE.csv  # write CSV to FILE.csv
```
