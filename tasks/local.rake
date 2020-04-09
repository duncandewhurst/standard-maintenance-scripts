REPOSITORY_CATEGORIES_WITHOUT_DOCS = [
  'Specifications',
  'Guides',
  'Templates',
  'Extensions',
  'Legacy',
]

TECH_SUPPORT_PRIORITIES = {
  # Specifications
  'data-quality-tool' => ' ', # issues only
  'glossary' => ' ', # documentation support
  'infrastructure' => '✴️✴️', # sector documentation
  'ocds-extensions' => ' ', # issues only
  'standard' => '✴️✴️✴️', # core documentation
  'translations' => ' ',

  # Guides
  'ocds-kibana-manual' => ' ',
  'ocds-r-manual' => ' ',

  # Tools
  'cove-ocds' => '✴️✴️✴️', # implementation step
  'cove-oc4ids' => '✴️✴️', # sectoral tool
  'jscc' => ' ',
  'kingfisher' => ' ',
  'kingfisher-archive' => ' ',
  'kingfisher-colab' => ' ',
  'kingfisher-process' => '✴️', # key tool
  'kingfisher-scrape' => '✴️', # key tool
  'kingfisher-views' => '✴️', # key tool
  'lib-cove-oc4ids' => '✴️✴️', # sectoral tool
  'lib-cove-ocds' => '✴️✴️✴️', # implementation step
  'ocds-merge' => '✴️✴️', # reference implementation
  'ocds-show' => ' ', # infrequently used
  'ocds-show-ppp' => ' ', # infrequently used
  'ocdskit' => '✴️', # key tool
  'toucan' => '✴️', # key tool
  'sample-data' => '✴️', # frequently used

  # Extension tools
  'extension-explorer' => '✴️✴️', # extensions documentation
  'extension_creator' => ' ', # infrequently used
  'extension_registry' => '✴️✴️', # authoritative resource
  'extension_registry.py' => '✴️✴️', # frequent dependency
  'ocds-extensions-translations' => '✴️✴️', # extensions documentation

  # Internal tools
  'deploy' => '✴️✴️✴️', # deployment dependency
  'european-union-support' => ' ', # scratch pad
  'json-schema-random' => ' ', # infrequently used
  'standard-development-handbook' => '✴️', # key internal documentation
  'standard-maintenance-scripts' => '✴️', # internal quality assurance

  # Templates
  'standard_extension_template' => '✴️', # public template
  'standard_profile_template' => ' ', # internal template
}

namespace :local do
  desc 'Report which non-extension repositories are not cloned'
  task :uncloned do
    basedir = variables('BASEDIR')[0]

    extension_repositories = Set.new
    url = 'https://standard.open-contracting.org/extension_registry/master/extensions.json'
    JSON.load(open(url).read).fetch('extensions').each do |extension|
      extension_repositories << URI.parse(extension['url']).path.split('/')[2]
    end

    cloned_repositories = Set.new(Dir[File.join(basedir, '*')].map{ |path| File.basename(path) })

    repos.each do |repo|
      if !extension_repositories.include?(repo.name) && !cloned_repositories.include?(repo.name)
        suffix = ''
        if repo.language
          suffix << " #{repo.language.bold}"
        end
        puts "#{repo.html_url}#{suffix}"
      end
    end
  end

  desc 'Regenerates the badges pages'
  task :badges do
    def tech_support_priority(repo)
      if extension?(repo.name, profiles: false, templates: false)
        if core_extensions[repo.full_name]
          '✴️✴️'
        else
          '✴️'
        end
      elsif profile?(repo.name)
        '✴️✴️'
      elsif DOCUMENTATION_DEPENDENCIES.include?(repo.name)
        '✴️✴️'
      elsif LEGACY.include?(repo.name)
        'N/A'
      else
        TECH_SUPPORT_PRIORITIES.fetch(repo.name)
      end
    end

    if ENV['ORG']
      filename = "badges-#{ENV['ORG']}.md"
    else
      filename = 'badges.md'
    end

    output = [
      '# Project Statuses',
    ]

    if ENV['ORG'] != 'open-contracting-partnership'
      output += [
        '',
        'Tech support priority is assessed based on the impact of the project becoming unavailable and the degree of usage, which can be assessed based on [Python package downloads](http://www.pypi-stats.com/author/?q=30327), [GitHub traffic](https://github.com/open-contracting/standard-development-handbook/issues/76#issuecomment-334540063) and user feedback.',
        '',
        'In addition to the below, within the [OpenDataServices](https://github.com/OpenDataServices) organization, `cove` is critical (as a step in implementation), and `sphinxcontrib-jsonschema` and `sphinxcontrib-opendataservices` are high (as dependencies of `standard`).'
      ]
    end

    REPOSITORY_CATEGORIES.each do |heading, condition|
      matches = repos.select(&condition)

      if matches.any?
        output += [
          '',
          "## #{heading}",
          '',
        ]

        if ENV['ORG'] == 'open-contracting-partnership'
          output += [
            '|Build|Name|',
            '|-|-|',
          ]
        elsif REPOSITORY_CATEGORIES_WITHOUT_DOCS.include?(heading)
          output += [
            '|Priority|Build|Name|',
            '|-|-|-|',
          ]
        else
          output += [
            '|Priority|Build|Docs|Name|',
            '|-|-|-|-|',
          ]
        end

        matches.each do |repo|
          line = '|'

          begin
            hooks = repo.rels[:hooks].get.data
          rescue Octokit::NotFound
            hooks = []
          end

          if ENV['ORG'] != 'open-contracting-partnership'
            priority = tech_support_priority(repo)

            line << "#{priority}|"
          end

          # Support both GitHub Services and GitHub Apps until GitHub Services fully retired.
          hook = hooks.find{ |datum| datum.name == 'travis' || datum.config.url == 'https://notify.travis-ci.org' }
          ci = read_github_file(repo.full_name, '.github/workflows/ci.yml')
          lint = read_github_file(repo.full_name, '.github/workflows/lint.yml')

          # https://github.com/octokit/octokit.rb/issues/1216
          if !ci.empty?
            line << "![Build Status](https://github.com/#{repo.full_name}/workflows/CI/badge.svg)"
            if hook
              puts client.remove_hook(repo.full_name, hook.id)
            end
          elsif !lint.empty?
            line << "![Build Status](https://github.com/#{repo.full_name}/workflows/Lint/badge.svg)"
            if hook
              puts client.remove_hook(repo.full_name, hook.id)
            end
          elsif hook
            line << "[![Build Status](https://travis-ci.org/#{repo.full_name}.svg)](https://travis-ci.org/#{repo.full_name})"
          end

          if !ci.empty? || !lint.empty? || hook
            if ['Tools', 'Extension tools', 'Internal tools', 'Documentation dependencies'].include?(heading)
              contents = read_github_file(repo.full_name, '.travis.yml')
              if contents.include?('coveralls')
                line << " [![Coverage Status](https://coveralls.io/repos/github/#{repo.full_name}/badge.svg?branch=master)](https://coveralls.io/github/#{repo.full_name}?branch=master)"
              end
              contents = read_github_file(repo.full_name, 'tox.ini')
              if contents.include?('coveralls')
                line << " [![Coverage Status](https://coveralls.io/repos/github/#{repo.full_name}/badge.svg?branch=master)](https://coveralls.io/github/#{repo.full_name}?branch=master)"
              end
            end
            line << '|'
          else
            line << '-|'
          end

          if ENV['ORG'] != 'open-contracting-partnership' && !REPOSITORY_CATEGORIES_WITHOUT_DOCS.include?(heading)
            hook = hooks.find{ |datum| datum.config.url && datum.config.url[%r{\Ahttps://readthedocs.org/api/v2/webhook/([^/]+)}] }
            if hook
              line << "[Docs](https://#{$1}.readthedocs.io/)"
              line << '|'
            else
              line << '-|'
            end
          end

          output << line + "[#{repo.name}](#{repo.html_url})|"

          print '.'
        end
      end
    end

    output << ''

    File.open(filename, 'w') do |f|
      f.write(output.join("\n"))
    end
  end
end
