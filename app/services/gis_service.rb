class GisService

  DEG2RAD             = 0.0174532925199433    # Pi / 180
  RAD2DEG             = 57.29577951308232     # 180 / Pi

  EARTHS_RADIUS_MILES = 3959      # earth's mean radius, miles
  EARTHS_RADIUS_KM    = 6371      # earth's mean radius, km

  DD_TO_MILES         = 65.5375   # Approximate number of miles in a decimal degree
  MILES_TO_METERS     = Uom.convert(1, Uom::MILE, Uom::METER)      # Number of meters in a mile
  MILES_TO_KM         = Uom.convert(1, Uom::MILE, Uom::KILOMETER)  # Number of kilometers in a mile
  MILES_TO_FEET       = Uom.convert(1, Uom::MILE, Uom::FEET)       # Number of feet in a mile

  # Allow an optional SRID to be configured. This will be added to all geometries created
  attr_accessor       :srid
  # Input unit
  attr_accessor       :input_unit
  # output_unit
  attr_accessor       :output_unit
  # klass being manipulated
  attr_accessor       :klass
  attr_accessor       :column_name
  attr_accessor       :geometry_factory

  def initialize(attrs = {})
    @input_unit = Uom::MILE
    @output_unit = Uom::MILE
    attrs.each do |k, v|
      self.send "#{k}=", v
    end
    # Create the geometry factory by using the adapter configured in the app and the default SRID
    @geometry_factory = TransamGeometryFactory.new(Rails.application.config.transam_spatial_geometry_adapter)
  end

  # Calculates a point at offset_m along the line segment (x0,y0),(x1,y1)
  # if the line segment is degenerate it retuns the start point (x0,y0) and
  # if the offset m is greater than length m it returns (x1,y1)
  def calculate_offset_along_line_segment(pt0, pt1, dist, offset_m)
    if offset_m < 0
      [pt0.x, pt0.y]
    elsif offset_m > dist
      [pt1.x, pt1.y]
    else
      # Using similar right triangles (where the line between pt0 and pt1 is the hypotenuse)
      # the ratio of offset_m/dist = offset_x / dist_x between pt0 and pt1 (similarly for offset_y)
      # thus we can calculate offset_x and offset_y and get the offset point

      # make all values floats
      dist = dist.to_f
      offset_m = offset_m.to_f

      if pt0.y == pt1.y         # check if horizontal line
        [pt0.x + offset_m, pt0.y]
      elsif pt0.x == pt1.x      # check if vertical line
        [pt0.x, pt0.y + offset_m]
      else
        offset_x = pt0.x + offset_m / dist * (pt1.x - pt0.x)
        offset_y = pt0.y + offset_m / dist * (pt1.y - pt0.y)
        [offset_x, offset_y]
      end
    end

  end
  # Calulates the euclidean distance between two points and convert the units to output units
  def euclidean_distance(point1, point2)
    dist = Uom.convert(point1.euclidean_distance(point2), @input_unit, @output_unit)
  end

  def from_wkt(wkt)
    Rails.logger.debug "WELL_KNOWN_TEXT '#{wkt}'"
    @geometry_factory.create_from_wkt(wkt)
  end

  def search_box_from_bbox(bbox)

    elems = bbox.split(",")
    puts elems.inspect

    minLon = elems[0].to_f
    minLat = elems[1].to_f
    maxLon = elems[2].to_f
    maxLat = elems[3].to_f

    coords = []
    coords << [minLon, minLat]
    coords << [minLon, maxLat]
    coords << [maxLon, maxLat]
    coords << [maxLon, minLat]
    coords << [minLon, minLat]
    as_polygon(coords, true)
  end

  # Returns a scale factor for converting decimal degrees to a unit of measure
  def self.convert_dd_to_uom(length, uom)
    Uom.convert(1, uom, Uom::MILE) * DD_TO_MILES * length
  end
  def self.convert_uom_to_dd(length, uom)
    Uom.convert(1, uom, Uom::MILE) / DD_TO_MILES * length
  end
  # Creates a Polygon geometry that can be used as a search box for spatial
  # queries. Defaults to mile
  def search_box_from_point(point, radius, unit = MILE)
    lat = point.lat
    lng = point.lon

    # Convert input units to miles and radians
    search_distance_in_miles = Uom.convert(radius, unit, MILE)
    search_distance_in_radians = search_distance_in_miles / EARTHS_RADIUS_MILES
    # Convert to decimal degrees, compensating for changes in latitude
    delta_lat = rad2deg(search_distance_in_radians)
    delta_lon = rad2deg(search_distance_in_radians/Math.cos(deg2rad(lat)))

    # bounding box (in degrees)
    maxLat = lat + delta_lat
    minLat = lat - delta_lat
    maxLon = lng + delta_lon
    minLon = lng - delta_lon

    coords = []
    coords << [minLon, minLat]
    coords << [minLon, maxLat]
    coords << [maxLon, maxLat]
    coords << [maxLon, minLat]
    coords << [minLon, minLat]
    as_polygon(coords, true)
  end

  # Converts a coordinate defined as a lat,lon into a Point geometry
  def as_point(lat, lon)
    @geometry_factory.create_point(lat, lon)
  end
  # Converts an array of coordinate pairs into a line string
  def as_linestring(coords)
    @geometry_factory.create_linestring(coords)
  end
  # Converts an array of coordinate pairs into a line string. Assumes the polygon
  # is not closed
  def as_polygon(coords, closed = false)
    @geometry_factory.create_polygon(coords, closed)
  end

  protected

  def rad2deg(r)
    r * RAD2DEG
  end

  def deg2rad(d)
    d * DEG2RAD
  end

end
