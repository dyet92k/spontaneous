# encoding: UTF-8


class HomePage < Spontaneous::Page
	field :welcome_title
  field :introduction, :markdown

  slot :in_progress, :type => :ClientProjects, :fields => { :title => "In Progress" }
  slot :completed, :type => :ClientProjects, :fields => { :title => "Completed" }
  slot :archived, :type => :ClientProjects, :fields => { :title => "Archived" }

  slot :pages do
  	allow :InfoPage
  end

  page_style :page

  def prototype
    # make sure things are working with a prototype method
  end
end

