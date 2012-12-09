class BubbleChart
  constructor: (data) ->
    @data = data
    @width = 940
    @height = 700
    
    Array::unique = ->
      output = {}
      output[@[key]] = @[key] for key in [0...@length]
      value for key, value of output
    
    organizators = []
    i = 0
    while i < @data.length
      organizators.push @data[i].organizator
      i++
    #console.log @data
    @organizators = organizators.unique()

    @tooltip = CustomTooltip("data-report", 240)

    # locations the nodes will move towards
    # depending on which view is currently being
    # used
    @center = {x: @width / 2, y: @height / 2}
    @year_centers = {
      "согласовано": {x: @width / 3, y: @height / 2},
      "не согласовано": {x: 2 * @width / 3, y: @height / 2}
    }

    # used when setting up force and
    # moving around nodes
    @layout_gravity = -0.01
    @damper = 0.1

    # these will be set in create_nodes and create_vis
    @vis = null
    @nodes = []
    @force = null
    @circles = null

    # nice looking colors - no reason to buck the trend
    @fill_color = d3.scale.ordinal()
      .domain(["За честные выборы", "Стратегия-31", "другое","Pussy Riot","антиПутин","политзеки","закон о митингах","социальная","экология","марш миллионов","ЛГБТ","оккупай"])
      .range(["#ecf8ff", "#fea61b", "#e4e4e4", "#fc78ea", "#323232", "#cc91f9", "#98a422", "#e33320", "#20cc1a", "#f8fdb3", "#76f7fb", "#6e72f7"])

    # use the max total_amount in the data as the max in the scale's domain
    max_amount = d3.max(@data, (d) -> parseInt(d.total))
    @radius_scale = d3.scale.pow().exponent(0.5).domain([0, max_amount]).range([2, 85])
    
    this.create_nodes()
    this.create_vis()

  # create node objects from original data
  # that will serve as the data behind each
  # bubble in the vis, then add each node
  # to @nodes to be used later
  create_nodes: () =>
    @data.forEach (d) =>
      node = {
        id: d.id
        radius: @radius_scale(parseInt(d.total))
        value: d.total
        name: d.subject
        org: d.organizator
        group: d.type
        year: d.agreement
        date: d.date
        comment: d.comment
        subject: d.subject
        x: Math.random() * 900
        y: Math.random() * 800
      }
      @nodes.push node

    @nodes.sort (a,b) -> b.value - a.value


  # create svg at #vis and then 
  # create circle representation for each node
  create_vis: () =>
    @vis = d3.select("#vis").append("svg")
      .attr("width", @width)
      .attr("height", @height)
      .attr("id", "svg_vis")

    @circles = @vis.selectAll("circle")
      .data(@nodes, (d) -> d.id)

    # used because we need 'this' in the 
    # mouse callbacks
    that = this

    # radius will be set to 0 initially.
    # see transition below
    @circles.enter().append("circle")
      .attr("r", 0)
      .attr("fill", (d) => @fill_color(d.subject))
      .attr("stroke-width", 2)
      .attr("fill-opacity", 0.9)
      .attr("stroke-opacity", 0.5)
      .attr("stroke", (d) => d3.rgb(@fill_color(d.subject)).darker())
      .attr("id", (d) -> "bubble_#{d.id}")
      .on("mouseover", (d,i) -> that.show_details(d,i,this))
      .on("mouseout", (d,i) -> that.hide_details(d,i,this))

    # Fancy transition to make bubbles appear, ending with the
    # correct radius
    @circles.transition().duration(2000).attr("r", (d) -> d.radius)


  # Charge function that is called for each node.
  # Charge is proportional to the diameter of the
  # circle (which is stored in the radius attribute
  # of the circle's associated data.
  # This is done to allow for accurate collision 
  # detection with nodes of different sizes.
  # Charge is negative because we want nodes to 
  # repel.
  # Dividing by 8 scales down the charge to be
  # appropriate for the visualization dimensions.
  charge: (d) ->
    -Math.pow(d.radius, 2.0) / 8

  # Starts up the force layout with
  # the default values
  start: () =>
    @force = d3.layout.force()
      .nodes(@nodes)
      .size([@width, @height])

  # Sets up force layout to display
  # all nodes in one circle.
  display_group_all: () =>
    that = this
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_center(e.alpha))
          .each(that.totalSort(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
          .attr("data-legend", (d) -> d.subject)
    @force.start()
    this.display_label()
    this.hide_years()
    this.hide_axis()

  # Moves all circles towards the @center
  # of the visualization
  move_towards_center: (alpha) =>
    (d) =>
      d.x = d.x + (@center.x - d.x) * (@damper + 0.02) * alpha
      d.y = d.y + (@center.y - d.y) * (@damper + 0.02) * alpha

  # sets the display of bubbles to be separated
  # into each year. Does this by calling move_towards_year
  display_by_year: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_year(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()
    
    this.hide_label()
    this.hide_axis()
    this.display_years()

  # move all circles to their associated @year_centers 
  move_towards_year: (alpha) =>
    (d) =>
      target = @year_centers[d.year]
      d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1
 
  B = new Date(2011,09,4)
  J = new Date(2012,10,4)
  yScale = d3.scale.linear().domain([0, 700]).range([@height, 0])
  xScale = d3.time.scale().domain([B, J]).range([10, @width])
  
  display_by_date: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_date(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()
    
    this.hide_label()
    this.hide_years()
    this.display_axis()
    
  move_towards_date: (alpha) =>
    (d) =>
      date = CoffeeDate.parse(d.date, "%d.%m.%Y")
      d.date2 = Date.parse(date.year + ',' + date.month + ',' + date.day)
      x = xScale d.date2
      y = yScale d.value
      d.x = d.x + (x - d.x) * (@damper + 0.001) 
      d.y = d.y + (y - d.y) * (@damper + 1) 
      
  display_by_type: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_type(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()
    this.hide_label()
    this.hide_years()
    this.hide_axis()
    
   move_towards_type: (alpha) =>
    (d) =>
      position = @organizators.indexOf(d.org)
#      switch position
#        when 1
#          targetY = 200
#          targetX = 200
#        when 2
#          targetY = 200
#          targetX = 400
#        when 3
#          targetY = 200
#          targetX = 600
#        when 4
#          targetY = 200
#          targetX = 800
#        when 5
#          targetY = 300
#          targetX = 200
#        when 6
#          targetY = 300
#          targetX = 400
#        when 7
#          targetY = 300
#          targetX = 600
#        when 8
#          targetY = 300
#          targetX = 800
#        when 9
#          targetY = 400
#          targetX = 200
#        when 10
#          targetY = 400
#          targetX = 300
#        when 11
#          targetY = 400
#          targetX = 400
#        when 12
#          targetY = 400
#          targetX = 500
#        when 13
#          targetY = 400
#          targetX = 600
#        when 14
#          targetY = 400
#          targetX = 700
#        when 15
#          targetY = 400
#          targetX = 800
#        when 16
#          targetY = 500
#          targetX = 200
#        when 17
#          targetY = 500
#          targetX = 400
#        when 18
#          targetY = 500
#          targetX = 600
#        else
#          targetY = 500
#          targetX = 800
      targetY = 100*Math.round(position/4)
      targetX = 200+200*(position%4)
      #console.log d.org
      d.y = d.y + (targetY - d.y) * Math.sin(Math.PI * (1 - alpha*10)) * 0.009
      d.x = d.x + (targetX - d.x) * Math.sin(Math.PI * (1 - alpha*10)) * 0.009
      
  display_label: () =>
    legend = d3.select("svg").append("g").attr("class", "legend").attr("transform", "translate(50,30)").style("font-size", "12px").call(d3.legend)
    setTimeout (->
      legend.call d3.legend
    ), 100
    
  hide_label: () =>
    legend = @vis.selectAll(".legend").remove() 
 
  display_axis: () =>
    margin =
      top: 19.5
      right: 19.5
      bottom: 19.5
      left: 39.5
    @width = 990
    @height = 600
    B = new Date(2011,09,4)
    J = new Date(2012,10,4)
    xScale = d3.time.scale().domain([B, J]).range([10, @width])
    yScale = d3.scale.linear().domain([0, 700]).range([@height, 0])
    radiusScale = d3.scale.sqrt().domain([0, 5e8]).range([0, 40])
    colorScale = d3.scale.category10()
    xAxis = d3.svg.axis().orient("bottom").scale(xScale).ticks(12, d3.format(",d"))
    yAxis = d3.svg.axis().scale(yScale).orient("left")
    @vis.attr("width", @width + margin.left + margin.right).attr("height", @height + margin.top + margin.bottom).append("g").attr("transform", "translate(" + margin.left + "," + margin.top + ")")
    @vis.append("g").attr("class", "x axis").attr("transform", "translate(40," + @height + ")").call xAxis
    @vis.append("g").attr("class", "y axis").attr("transform", "translate(50,0)").call yAxis
    @vis.append("text").attr("class", "x label").attr("text-anchor", "end").attr("x", @width).attr("y", @height - 6).text "дата мониторинга"
    @vis.append("text").attr("class", "y label").attr("text-anchor", "end").attr("y", 6).attr("dy", ".75em").attr("transform", "rotate(-90)").text "количество задержаний"
  
  hide_axis: () =>
    axis = @vis.selectAll(".axis").remove()
    label = @vis.selectAll(".label").remove() 
 
 
  # Method to display year titles
  display_years: () =>
    years_x = {"согласовано": 160, "не согласовано": @width - 160}
    years_data = d3.keys(years_x)
    years = @vis.selectAll(".years")
      .data(years_data)

    years.enter().append("text")
      .attr("class", "years")
      .attr("x", (d) => years_x[d] )
      .attr("y", 40)
      .attr("text-anchor", "middle")
      .text((d) -> d)

  # Method to hide year titiles
  hide_years: () =>
    years = @vis.selectAll(".years").remove()

  show_details: (data, i, element) =>
    d3.select(element).attr("stroke", "black")
    content ="<div id=\"tooltipContainer\">"
    content +="<div class=\"data-type\">#{data.comment}</div>"
    content +="<div class=\"data-rule\"></div>"
    content +="<div class=\"data-date\">#{data.date}</div>"
    content +="<div class=\"data-desc\">Количество задержанных</div>"
    content +="<div class=\"data-valuesContainer\"><span class=\"data-value\">#{data.value}</span></div>"
    content +="<div class=\"data-tail\"></div>"
    content +="</div>"
    @tooltip.showTooltip(content,element)


  hide_details: (data, i, element) =>
    d3.select(element).attr("stroke", (d) => d3.rgb(@fill_color(d.group)).darker())
    @tooltip.hideTooltip()
    
    
  totalSort: (alpha) ->
    that = this
    (d) ->
      targetY = that.centerY
      targetX = that.width / 2
      #if d.subject is "За честные выборы"
       # d.y = 200

root = exports ? this

$ ->
  chart = null

  render_vis = (csv) ->
    chart = new BubbleChart csv
    chart.start()
    root.display_all()
  root.display_all = () =>
    chart.display_group_all()
  root.display_year = () =>
    chart.display_by_year()
  root.display_chron = () =>
    chart.display_by_date()
  root.display_type = () =>
    chart.display_by_type()
  root.toggle_view = (view_type) =>
    if view_type == 'cons'
      root.display_year()
    else if view_type == 'all'
      root.display_all()
    else if view_type == 'chron'
      root.display_chron()
    else if view_type == 'type'
      root.display_type()

  d3.csv "data/data.csv", render_vis
