# The response schemas of the v1 API, one named character vector each:
# field name = type. The types are
#
#   chr num int int64 lgl dttm date   scalars (int64 is kept as a double);
#   json                               free-form JSON, kept as parsed lists
#                                      (also maps such as a snowpack's
#                                      `definitions`, and GeoJSON coordinates);
#   <Schema>                           a nested object of another schema;
#   <type>[]                           an array (of strings, a character
#                                      vector; of objects, a tibble; of
#                                      arrays, kept as parsed lists);
#   <Schema>?[]                        an array of objects that may hold null
#                                      items (a null item is a row of NAs);
#
# and a trailing "!" marks a field the schema requires (it may still be null).
#
# Field names are the package's names. They are the wire's names except the
# stuttering ones of spec BEHAVIOR.md 3.0 (`forecast` is `series`, `current`
# is `now`, `alerts` is `items`, ...): `wire_names` maps those back to the
# name the API sends, and the decoder reads that name.
#
# A schema the spec defines inline (CurrentConditions.station, a model's
# members, a snow-trend run, ...) has a table of its own, named here.
# tests/testthat/test-spec-drift.R checks every name and requirement here,
# through `wire_names`, against the pinned spec/openapi/v1/openapi.yaml, so
# this table cannot drift from the contract. Enumerations are plain strings:
# a value added to the API later comes through as it is, never as an error.

schemas <- list(
  ActiveAlert = c(
    id = "chr!", event = "chr!", severity = "chr!", urgency = "chr!", certainty = "chr!",
    headline = "chr!", onset = "dttm", expires = "dttm!", ends = "dttm", sent = "dttm",
    message_type = "chr", references = "chr[]", sender_name = "chr", area_desc = "chr",
    description = "chr", instruction = "chr", source_url = "chr", event_key = "chr",
    vtec_action = "chr"
  ),
  AlertOutlineCollection = c(
    type = "chr!", features = "AlertOutlineFeature[]!", attribution = "ResponseAttribution!"
  ),
  AlertOutlineFeature = c(
    type = "chr!", geometry = "AlertOutlineGeometry!", properties = "AlertOutlineProperties!"
  ),
  AlertOutlineGeometry = c(
    type = "chr!", coordinates = "json[][][]!"
  ),
  AlertOutlineProperties = c(
    id = "chr!", event = "chr!", class = "chr!", severity = "chr!", urgency = "chr!",
    certainty = "chr!", headline = "chr!", onset = "dttm", expires = "dttm!", ends = "dttm",
    sender_name = "chr", source_url = "chr!"
  ),
  NearestLocation = c(
    slug = "chr!", url = "chr!", distance_km = "num!", elevation_m = "num!"
  ),
  LocationRef = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!", elevation_m = "num!",
    type = "chr!", timezone = "chr!"
  ),
  ForecastLocation = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!", elevation_m = "num!",
    type = "chr!", timezone = "chr!", elevation = "num!", elevations = "ElevationSummary[]"
  ),
  ElevationSummary = c(
    name = "chr!", display_name = "chr", height = "num!", default = "lgl"
  ),
  CurrentResponse = c(
    location = "LocationRef!", alerts = "ActiveAlert[]!", alerts_as_of = "dttm!",
    sensor_count = "int!", sensors = "SensorObservation[]!", now = "CurrentConditions!",
    as_of = "dttm!", model_run_initialized_at = "dttm!", nowcast_hours = "TimeSeriesPoint[]",
    units = "chr!", attribution = "ResponseAttribution!", nowcast_unavailable = "chr[]",
    summary = "PlaceSummary", pass = "PassForecast"
  ),
  PlaceSummary = c(
    short = "chr!", long = "chr[]!", events = "SummaryEvent[]!", elevation_name = "chr",
    elevation = "num!", run = "dttm!", generated_at = "dttm!"
  ),
  SummaryEvent = c(
    kind = "chr!", template = "chr!", at = "dttm", until = "dttm", alert_id = "chr",
    values = "SummaryValues"
  ),
  SummaryValues = c(
    snowfall = "num", snowfall_p10 = "num", snowfall_p90 = "num", snowfall_window = "chr",
    temperature = "num", wind_gust = "num", precipitation_probability = "num"
  ),
  PassForecast = c(
    elevation = "num!", elevation_m = "num!", from = "dttm!", snow_24h = "PassSnow24h!",
    chances = "PassChances!", snow_windows = "PassSnowWindow[]!", hours = "PassHour[]!",
    windows = "PassTravelWindows!", official_status = "PassOfficialStatus",
    road_sensors = "PassRoadSensor[]", cameras = "PassCamera[]"
  ),
  PassSnow24h = c(
    total = "num!", p10 = "num!", p90 = "num!", starts_at = "dttm!"
  ),
  PassChances = c(
    window_hours = "int!", from = "dttm!", to = "dttm!", p_snow_ge_1in = "PassChance!",
    p_snow_ge_6in = "PassChance!", p_wet_below_freezing = "PassChance!",
    p_gust_gt_40mph = "PassChance!"
  ),
  PassChance = c(
    probability = "num!", threshold = "num!", precipitation_threshold = "num", members = "int!",
    method = "chr!", null_reason = "chr"
  ),
  PassSnowWindow = c(
    start = "dttm!", end = "dttm!", total = "num!", p10 = "num", p90 = "num", p_ge_1in = "num"
  ),
  PassHour = c(
    time = "dttm!", temperature = "num!", precipitation = "num!",
    precipitation_probability = "num", precipitation_type = "chr", snowfall = "num!",
    snow_level = "num", snow_level_margin = "num", freezing_on_wet_road = "lgl!",
    wind_speed = "num!", wind_gust = "num", gust_over_40mph = "lgl!", blowing_snow = "lgl!"
  ),
  PassTravelWindows = c(
    horizon_hours = "int!", least_weather = "PassTravelWindow!", most_weather = "PassTravelWindow!"
  ),
  PassTravelWindow = c(
    start = "dttm!", end = "dttm!", snowfall = "num!", freezing_on_wet_road_hours = "int!",
    max_wind_gust = "num"
  ),
  PassOfficialStatus = c(
    source = "chr!", attribution = "chr!", url = "chr!", checked_at = "dttm!", stale = "lgl!",
    level = "chr!", segments = "PassStatusSegment[]!"
  ),
  PassStatusSegment = c(
    id = "chr!", route = "chr!", direction = "chr!", location = "chr!", state = "chr!",
    level = "chr!", text = "chr!", updated_at = "dttm!", lat = "num!", lon = "num!",
    road_condition = "chr", weather_condition = "chr"
  ),
  PassCamera = c(
    id = "chr!", title = "chr!", image_url = "chr!", url = "chr!", captured_at = "dttm",
    stale = "lgl!", source = "chr!", attribution = "chr!"
  ),
  PassRoadSensor = c(
    station_id = "chr!", name = "chr!", source = "chr!", attribution = "chr!",
    distance_km = "num!", elevation = "num", elevation_m = "num", observed_at = "dttm!",
    stale = "lgl!", pavement_condition = "chr", pavement_temp = "num", subsurface_temp = "num",
    temperature = "num", wind_speed = "num", wind_gust = "num", wind_direction = "num",
    visibility = "num"
  ),
  AlertsResponse = c(
    location = "LocationRef!", count = "int!", as_of = "dttm!", items = "ActiveAlert[]!",
    attribution = "ResponseAttribution!"
  ),
  SearchLocationsResponse = c(
    items = "SearchHit[]!", count = "int!"
  ),
  PublicCatalogLocationPage = c(
    items = "PublicCatalogLocation[]!", next_cursor = "chr!"
  ),
  PublicCatalogStationPage = c(
    items = "PublicCatalogStation[]!", next_cursor = "chr!"
  ),
  SnowTrendResponseElevation = c(
    name = "chr!", display_name = "chr", height = "num!"
  ),
  SnowTrendResponse = c(
    location = "LocationRef!", units = "chr!", elevation = "SnowTrendResponseElevation!",
    retention_days = "int!", dates = "date[]!", grids = "SnowTrendGrid[]!"
  ),
  SnowTrendRun = c(
    backfilled = "lgl!", initialized_at = "dttm!", days = "SnowTrendDay?[]!"
  ),
  SnowTrendGrid = c(
    source = "chr!", runs = "SnowTrendRun[]!"
  ),
  SnowTrendDay = c(
    date = "date!", amount = "num!", partial = "lgl!", p10 = "num", p90 = "num", kind = "chr"
  ),
  SnowpackPlumeDepth = c(
    start_time = "dttm!", interval_hours = "int!", members = "int[]!", p50 = "num[]",
    mean = "num[]!", p10 = "num[]!", p25 = "num[]!", p75 = "num[]!", p90 = "num[]!"
  ),
  SnowpackPlumeModel = c(
    id = "chr!", member_ids = "int[]!", depth = "num[][]!", depth_mean = "num[]!",
    members_skipped = "int!"
  ),
  SnowpackPlumeResponse = c(
    beta = "lgl!", location = "LocationRef!", units = "chr!", model_run = "SnowpackRun",
    stale = "lgl!", depth = "SnowpackPlumeDepth", models = "SnowpackPlumeModel[]",
    member_depths = "num[][]", spread = "chr!"
  ),
  SeasonResponse = c(
    location = "LocationRef!", water_year = "int!", starts = "date!", through = "date!",
    as_of = "dttm!", units = "chr!", precipitation = "SeasonTotal!", snowfall = "SeasonTotal!",
    station = "SeasonStation!", daily = "SeasonDay[]", attribution = "ResponseAttribution!"
  ),
  SeasonTotal = c(
    amount = "num!", unit = "chr!", source = "chr!", days_covered = "int!", days_missing = "int!",
    provisional_days = "int!", normal_to_date = "num!", percent_of_normal = "int!",
    normal_source = "chr!"
  ),
  SeasonStation = c(
    id = "chr!", network = "chr!", name = "chr!", distance_km = "num!", elevation_m = "num!",
    precipitation_total = "num!", precipitation_percent_of_median = "int!", swe = "num!",
    swe_percent_of_median = "int!", snow_depth = "num!", through = "date!"
  ),
  SeasonDay = c(
    date = "date!", precipitation = "num!", snowfall = "num!", provisional = "lgl!"
  ),
  SnowpackDefinitions = c(
    surface = "json!", layer_form = "json!"
  ),
  SnowpackResponse = c(
    beta = "lgl!", location = "LocationRef!", units = "chr!", model_run = "SnowpackRun",
    stale = "lgl!", spots = "SnowpackSpot[]!", definitions = "SnowpackDefinitions!"
  ),
  SnowpackModel = c(
    name = "chr!", by = "chr!", license = "chr!", version = "chr"
  ),
  SnowpackRun = c(
    initialized_at = "dttm!", generated_at = "dttm!", model = "SnowpackModel!"
  ),
  SnowpackAnchor = c(
    station = "chr!", name = "chr!", network = "chr!"
  ),
  SnowpackSpot = c(
    name = "chr!", display_name = "chr", elevation = "num!", elevation_m = "num!",
    initialized_at = "dttm!", anchor = "SnowpackAnchor", depth = "SnowpackDepth!",
    depth_change_24h = "num", swe = "num[]!", steps = "SnowpackStep[]!",
    layers = "SnowpackLayer[]!", aspects = "SnowpackAspect[]"
  ),
  SnowpackAspect = c(
    aspect = "chr!", slope_angle_deg = "num!", depth = "SnowpackDepth!", depth_change_24h = "num",
    steps = "SnowpackStep[]!", layers = "SnowpackLayer[]!"
  ),
  SnowpackDepth = c(
    start_time = "dttm!", interval_hours = "int!", basis = "chr!", p10 = "num[]", p50 = "num[]!",
    p90 = "num[]"
  ),
  SnowpackStep = c(
    valid_time = "dttm!", surface = "chr!", new_snow_24h = "num!", new_snow_density_kg_m3 = "num",
    settlement_24h = "num"
  ),
  SnowpackLayer = c(
    form = "chr!", thickness = "num!", depth = "num!", formed = "date!"
  ),
  CompositionResponse = c(
    initialized_at = "dttm!", models = "ModelEntry[]!", model_count = "int!",
    total_members = "int!"
  ),
  RunsServed = c(
    initialized_at = "dttm!", models = "ModelEntry[]!"
  ),
  RunEntry = c(
    initialized_at = "dttm!"
  ),
  RunsResponse = c(
    served = "RunsServed!", items = "RunEntry[]!", count = "int!", next_cursor = "chr!"
  ),
  NearbyPointResponse = c(
    lat = "num!", lon = "num!", radius_km = "num!", count = "int!", items = "NearbyLocation[]!"
  ),
  LocationsResponse = c(
    state = "chr!", count = "int!", items = "LocationSummary[]!", next_cursor = "chr!"
  ),
  NearbyLocationsResponse = c(
    origin = "LocationSummary!", radius_km = "num!", count = "int!", items = "NearbyLocation[]!"
  ),
  NearbyLocation = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!", elevation_m = "num!",
    type = "chr!", timezone = "chr!", county = "chr!", description = "chr",
    elevations = "ElevationSummary[]", distance_km = "num!"
  ),
  LocationSummary = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!", elevation_m = "num!",
    type = "chr!", timezone = "chr!", county = "chr!", description = "chr",
    elevations = "ElevationSummary[]"
  ),
  ProbabilityResult = c(
    term = "chr!", variable = "chr!", op = "chr!", threshold = "num!", window_start_hours = "int!",
    window_end_hours = "int!", aggregation = "chr!", from = "dttm!", to = "dttm!", value = "num!",
    members = "int!", null_reason = "chr!"
  ),
  WindowTotal = c(
    term = "chr!", variable = "chr!", start_hours = "int!", end_hours = "int!",
    aggregation = "chr!", from = "dttm!", to = "dttm!", quantiles = "Quantiles!", members = "int!",
    method = "chr!", null_reason = "chr!"
  ),
  Quantiles = c(
    mean = "num!", p10 = "num!", p25 = "num!", p50 = "num!", p75 = "num!", p90 = "num!",
    min = "num!", max = "num!", probability = "num"
  ),
  PrecipDisplay = c(
    kind = "chr!", chance = "num!", amount = "num", snow_amount = "num"
  ),
  ProbabilityThresholds = c(
    hourly_precipitation = "num!", hourly_snowfall = "num!", daily_precipitation = "num!",
    daily_precipitation_occurrence = "num!", daily_snow = "num!"
  ),
  AppliedOptions = c(
    max_hours = "int!", max_days = "int!", clamped = "chr[]!"
  ),
  ForecastResponse = c(
    thresholds = "ProbabilityThresholds", probabilities = "ProbabilityResult[]",
    window_totals = "WindowTotal[]", applied = "AppliedOptions", location = "ForecastLocation!",
    model_run = "ModelRunInfo!", units = "chr!", series = "ForecastData!",
    elevations = "ElevationForecast[]", nowcast_applied = "lgl!", nowcast_unavailable = "chr[]",
    members_view = "chr", gap_flow = "GapFlow", nearest_sensors = "NearestSensor[]",
    point = "PointInfo", current = "CurrentConditions", avalanche = "AvalancheForecast",
    snow_on_ground = "SnowOnGround", attribution = "ResponseAttribution!"
  ),
  SnowOnGround = c(
    beta = "lgl!", depth = "num!", basis = "chr!", surface = "chr", valid_time = "dttm!",
    generated_at = "dttm!"
  ),
  GapFlow = c(
    status = "chr!", pressure_diff_hpa = "num!", wind_multiplier = "num!", direction = "chr!"
  ),
  DailyWind = c(
    status = "chr!", peak_speed = "num!", peak_speed_p90 = "num", is_gust = "lgl!",
    sustained_speed = "num"
  ),
  AvalancheForecast = c(
    center_id = "chr!", center_name = "chr!", zone_id = "int64!", zone_name = "chr!",
    danger_level = "int!", danger_label = "chr!", status = "chr!", valid_from = "dttm!",
    valid_until = "dttm!", url = "chr!", center_url = "chr!", attribution = "chr!"
  ),
  AvalancheZoneCollection = c(
    type = "chr!", features = "AvalancheZoneFeature[]!", attribution = "ResponseAttribution!"
  ),
  AvalancheZoneFeature = c(
    type = "chr!", id = "int64!", geometry = "AvalancheZoneGeometry!",
    properties = "AvalancheForecast!"
  ),
  AvalancheZoneGeometry = c(
    type = "chr!", coordinates = "json[][][]!"
  ),
  ResponseAttribution = c(
    sources = "chr[]!", credit = "chr!", url = "chr!"
  ),
  AttributionRegistry = c(
    providers = "AttributionProvider[]!"
  ),
  AttributionProvider = c(
    id = "chr!", name = "chr!", credit = "chr!", licence = "chr!", licence_url = "chr!",
    terms_url = "chr!", modified = "lgl!", notices = "chr[]!", sources = "AttributionSource[]!"
  ),
  AttributionSource = c(
    id = "chr!", name = "chr!", kind = "chr!", provider = "chr!"
  ),
  SensorObservation = c(
    station_id = "chr!", name = "chr!", source = "chr!", observed_at = "dttm!",
    distance_km = "num!", elevation_diff = "num", temperature = "num", dewpoint = "num",
    relative_humidity = "num", wind_speed = "num", wind_gust = "num", wind_direction = "num",
    pressure = "num", precipitation = "num", precipitation_rate = "num", reflectivity = "num",
    pavement_temp = "num", subsurface_temp = "num", visibility = "num", cloud_cover = "num",
    ceiling_height = "num", snow_depth = "num", swe = "num", swe_percent_of_median = "num",
    snowfall = "num", solar_radiation = "num", pavement_condition = "chr"
  ),
  CurrentStation = c(
    id = "chr!", name = "chr!", observation_time = "dttm!", calm = "lgl!"
  ),
  CurrentConditions = c(
    time = "dttm!", temperature = "num!", feels_like = "num", code = "chr!", text = "chr!",
    icon = "chr!", wind_speed = "num!", wind_gust = "num", wind_direction = "num!",
    relative_humidity = "num", dewpoint = "num", precipitation_probability = "num",
    measured = "lgl!", cloud_cover = "num", source = "chr!", station = "CurrentStation"
  ),
  PointInfo = c(
    requested_lat = "num!", requested_lon = "num!", lat = "num!", lon = "num!",
    resolution_deg = "num!", elevation = "num!", elevation_source = "chr!", state = "chr!"
  ),
  NearestSensor = c(
    station_id = "chr!", name = "chr!", source = "chr!", distance_km = "num!",
    elevation_diff = "num!", effective_distance_km = "num!", observation_time = "dttm!"
  ),
  ModelRunInfo = c(
    initialized_at = "dttm!", total_members = "int!", models = "ModelEntry[]!"
  ),
  ModelEntry = c(
    id = "chr!", cycle = "dttm", members = "int", display_members = "int[]",
    display_members_snowfall = "chr"
  ),
  ForecastData = c(
    max_hours = "int!", interval_hours = "int!", timeseries = "TimeSeriesPoint[]",
    daily = "DailyForecast[]", snow_outlook = "SnowOutlook",
    precipitation_outlook = "PrecipOutlook", plume = "MemberPlume"
  ),
  SnowOutlook = c(
    next_24h = "num!", next_48h = "num!", next_72h = "num!", next_7d = "num!",
    overnight_4pm_9am = "num", quantiles = "SnowOutlookQuantiles"
  ),
  SnowOutlookQuantiles = c(
    next_24h = "Quantiles!", next_48h = "Quantiles!", next_72h = "Quantiles!",
    next_7d = "Quantiles!"
  ),
  PrecipOutlook = c(
    next_24h = "num!", next_48h = "num!", next_72h = "num!", next_7d = "num!",
    quantiles = "SnowOutlookQuantiles"
  ),
  ModelMembers = c(
    id = "chr!", items = "MemberForecast[]!"
  ),
  TimeSeriesPoint = c(
    valid_time = "dttm!", lead_time_hours = "int!", is_night = "lgl!", measured = "lgl!",
    condition = "chr!", condition_text = "chr!", condition_icon = "chr!", gust_notable = "lgl",
    precipitation_type = "PrecipType", snow_character = "chr", inversion = "InversionInfo",
    freezing_level = "FreezingLevel", ensemble = "EnsembleStats!", provenance = "HourProvenance",
    model_means = "ModelMeansEntry[]", members = "ModelMembers[]",
    members_cumulative = "MembersCumulative", members_spread = "MembersSpread",
    members_6h = "MembersCumulative", precipitation_by_type = "PrecipitationByType",
    cumulative_precipitation = "num", cumulative_snowfall = "num"
  ),
  HourProvenance = c(
    densified = "lgl", ngr = "chr[]", fallback = "chr[]", borrowed = "chr[]",
    spread_floored = "chr[]", floor_clamped = "chr[]", bucket_split = "chr[]",
    distribution_parameters = "chr[]", spread_interpolated = "chr[]",
    interpolated_contributor = "chr[]", moment_matched_family = "chr[]", lapse_profile = "chr[]",
    lapse_climatology = "chr[]", lapse_prism = "chr[]", spread_clamped_low = "chr[]",
    spread_clamped_high = "chr[]", gust_dressed = "chr[]"
  ),
  Sector = c(
    from = "num!", to = "num!"
  ),
  CircularStats = c(
    mean = "num!", stddev = "num", sector_50 = "Sector!", sector_90 = "Sector!"
  ),
  MemberForecast = c(
    id = "int!", temperature = "num!", precipitation = "num!", precipitation_hours = "int",
    wind_speed = "num", wind_direction = "num", snow_level = "num!", snow_level_wet_bulb = "num",
    slr = "num", snowfall = "num", cumulative_precipitation = "num", cumulative_snowfall = "num"
  ),
  MembersCumulative = c(
    precipitation = "MemberQuantiles", snowfall = "MemberQuantiles"
  ),
  MembersSpread = c(
    temperature = "MemberQuantiles", snow_level = "MemberQuantiles",
    snow_level_wet_bulb = "MemberQuantiles", slr = "MemberQuantiles",
    wind_speed = "MemberQuantiles"
  ),
  PrecipitationByType = c(
    rain = "num!", snow = "num!", rain_snow_mix = "num!", freezing_rain = "num!"
  ),
  InversionInfo = c(
    kind = "chr!", depth = "num!", strength = "num!"
  ),
  PrecipType = c(
    type = "chr!", snow_probability = "num!", rain_probability = "num!"
  ),
  EnsembleStats = c(
    temperature = "Quantiles!", feels_like = "Quantiles", dewpoint = "Quantiles!",
    precipitation = "Quantiles!", wind_speed = "Quantiles!", wind_gust = "Quantiles",
    wind_direction = "CircularStats!", snow_level = "Quantiles!",
    snow_level_wet_bulb = "Quantiles", slr = "Quantiles", snowfall = "Quantiles",
    cloud_cover = "Quantiles", skin_temperature = "Quantiles", mslp = "Quantiles",
    cape = "Quantiles", relative_humidity = "Quantiles"
  ),
  ModelStats = c(
    temperature = "Quantiles", dewpoint = "Quantiles", precipitation = "Quantiles",
    wind_speed = "Quantiles", wind_direction = "CircularStats", snow_level = "Quantiles",
    snow_level_wet_bulb = "Quantiles", slr = "Quantiles", snowfall = "Quantiles",
    interpolated = "lgl"
  ),
  SnowLevelRange = c(
    low = "num!", high = "num!", mean = "num!"
  ),
  MeasuredPrecipitation = c(
    amount = "num!", through = "dttm!"
  ),
  DailyForecast = c(
    date = "date!", covered_from = "dttm", measured_precipitation = "MeasuredPrecipitation",
    condition = "chr!", condition_text = "chr!", condition_icon = "chr!",
    precipitation_type = "chr", high = "Quantiles!", low = "Quantiles!",
    feels_like_high = "Quantiles", feels_like_low = "Quantiles",
    total_precipitation = "Quantiles!", total_snowfall = "Quantiles", snow_character = "chr",
    slr = "num", precipitation_probability = "num!", precipitation_occurrence_probability = "num!",
    snow_probability = "num!", snow_level_mean = "num!", snow_level = "Quantiles",
    snow_level_range = "SnowLevelRange", snow_level_wet_bulb = "Quantiles",
    snow_level_wet_bulb_range = "SnowLevelRange", total_precipitation_if_wet = "Quantiles",
    total_snowfall_if_wet = "Quantiles", precipitation_display = "PrecipDisplay!",
    cloud_cover_mean = "num", wind = "DailyWind", storm_orientation = "chr",
    storm_orientation_description = "chr", astro = "DailyAstro!",
    temperature_climatology = "DayClimatology", normal = "DayNormal", departure = "DayDeparture",
    percentile = "DayPercentile"
  ),
  DailyAstro = c(
    sunrise = "dttm", sunset = "dttm", moon_phase = "chr!", moon_illumination = "num!",
    astronomical_season = "chr!"
  ),
  DayNormal = c(
    high = "num", low = "num", precipitation = "num", source = "chr!", distance_km = "num!"
  ),
  DayDeparture = c(
    high = "num", low = "num"
  ),
  DayPercentile = c(
    high = "num", low = "num", precipitation = "num"
  ),
  DayClimatology = c(
    mean = "num!", std = "num!"
  ),
  MemberPlume = c(
    headline = "PlumeHeadline!", bands = "PlumeBands!", models = "ModelColumns[]!",
    pool = "PooledColumns"
  ),
  PooledColumns = c(
    valid_time = "dttm[]!", temperature = "num[][]!", precipitation = "num[][]!",
    precipitation_hours = "int[][]!", cumulative_precipitation = "num[][]!",
    snow_level = "num[][]!", snow_level_wet_bulb = "num[][]!", snowfall = "num[][]!",
    cumulative_snowfall = "num[][]!", slr = "num[][]!",
    cumulative_precipitation_band_members = "int[]!", cumulative_snowfall_band_members = "int[]!",
    cumulative_snowfall_10to1_band_members = "int[]!"
  ),
  PlumeHeadline = c(
    valid_time = "dttm[]!", temperature = "num[]!", snow_level = "num[]!",
    snow_level_wet_bulb = "num[]!", cumulative_precipitation = "num[]!",
    cumulative_snowfall = "num[]!", cumulative_snowfall_10to1 = "num[]!", wind_speed = "num[]!",
    snowfall_6h = "num[]!"
  ),
  PlumeBands = c(
    valid_time = "dttm[]!", cumulative_precipitation = "BandColumns!",
    cumulative_snowfall = "BandColumns!", cumulative_snowfall_10to1 = "BandColumns!",
    temperature = "BandColumns!", snow_level = "BandColumns!",
    snow_level_wet_bulb = "BandColumns!", precipitation_6h = "BandColumns!",
    snowfall_6h = "BandColumns!", slr = "BandColumns", wind_speed = "BandColumns"
  ),
  MemberQuantiles = c(
    mean = "num!", p10 = "num!", p25 = "num!", p50 = "num", p75 = "num!", p90 = "num!",
    min = "num!", max = "num!", probability = "num"
  ),
  BandColumns = c(
    mean = "num[]!", min = "num[]!", p10 = "num[]!", p25 = "num[]!", p50 = "num[]", p75 = "num[]!",
    p90 = "num[]!", max = "num[]!"
  ),
  ModelColumns = c(
    id = "chr!", valid_time = "dttm[]!", member_ids = "int[]!", temperature = "num[][]!",
    precipitation = "num[][]!", precipitation_hours = "int[][]!",
    cumulative_precipitation = "num[][]!", snow_level = "num[][]!",
    snow_level_wet_bulb = "num[][]!", snowfall = "num[][]!", cumulative_snowfall = "num[][]!",
    cumulative_snowfall_p50 = "num[]!", cumulative_snowfall_10to1_p50 = "num[]!",
    temperature_mean = "num[]!", precipitation_mean = "num[]!",
    cumulative_precipitation_mean = "num[]!", snow_level_mean = "num[]!",
    snow_level_wet_bulb_mean = "num[]!", snowfall_mean = "num[]!",
    cumulative_snowfall_mean = "num[]!", cumulative_snowfall_10to1_mean = "num[]!",
    wind_speed_mean = "num[]", cumulative_precipitation_band_member_ids = "int[]!",
    cumulative_snowfall_band_member_ids = "int[]!",
    cumulative_snowfall_10to1_band_member_ids = "int[]!", wind_speed = "num[][]",
    wind_direction = "num[][]", slr = "num[][]"
  ),
  ElevationForecast = c(
    name = "chr!", display_name = "chr", height = "num!", lat = "num!", lon = "num!",
    hourly = "TimeSeriesPoint[]", daily = "DailyForecast[]", nearest_sensors = "NearestSensor[]",
    snow_outlook = "SnowOutlook", precipitation_outlook = "PrecipOutlook", plume = "MemberPlume",
    snow_on_ground = "SnowOnGround"
  ),
  SearchHit = c(
    key = "chr!", slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!",
    elevation_m = "num!", type = "chr!", timezone = "chr!", county = "chr!",
    explore = "ExploreValue"
  ),
  ExploreValue = c(
    metric = "chr!", value = "num!", unit = "chr!", p10 = "num", p90 = "num", as_of = "dttm!",
    initialized_at = "dttm!", source = "chr!"
  ),
  ExploreResponse = c(
    metric = "chr!", order = "chr!", units = "chr!", unit = "chr!", items = "ExploreItem[]!",
    count = "int!", next_cursor = "chr!"
  ),
  ExploreItem = c(
    rank = "int!", location = "LocationRef!", elevation_name = "chr!",
    elevation_display_name = "chr", elevation = "num!", value = "num!", p10 = "num", p90 = "num",
    as_of = "dttm!", initialized_at = "dttm!", source = "chr!", distance_km = "num", path = "chr!"
  ),
  PublicCatalogLocation = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!", elevation_m = "num!",
    type = "chr!", timezone = "chr!", county = "chr", country = "chr", aliases = "chr[]",
    description_short = "chr", description_long = "chr", microclimate_notes = "chr",
    meta_title = "chr", meta_description = "chr", best_seasons = "chr[]", key_factors = "chr[]",
    tags = "chr[]", external_links = "json", is_featured = "lgl"
  ),
  PublicCatalogLocationDetail = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!", elevation_m = "num!",
    type = "chr!", timezone = "chr!", county = "chr", country = "chr", aliases = "chr[]",
    description_short = "chr", description_long = "chr", microclimate_notes = "chr",
    meta_title = "chr", meta_description = "chr", best_seasons = "chr[]", key_factors = "chr[]",
    tags = "chr[]", external_links = "json", is_featured = "lgl",
    elevations = "PublicCatalogElevation[]!", photos = "PublicCatalogPhoto[]!",
    webcams = "PublicCatalogWebcam[]!", nearby_stations = "PublicCatalogNearbyStation[]!",
    template = "CatalogTemplateSummary", content = "CatalogResolvedEntry[]"
  ),
  PublicCatalogStation = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!", elevation_m = "num!",
    type = "chr!", timezone = "chr!", county = "chr", country = "chr", aliases = "chr[]",
    network = "chr", source_id = "chr", elevation_msl_m = "num", sensor_height_agl_m = "num",
    sensor_capabilities = "chr[]", status = "chr", last_report_at = "dttm",
    last_report_summary = "json", install_date = "date", decommission_date = "date",
    update_frequency_minutes = "int", url = "chr", data_url = "chr", description_short = "chr",
    description_long = "chr", meta_title = "chr", meta_description = "chr", tags = "chr[]",
    is_featured = "lgl"
  ),
  PublicCatalogStationDetail = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!", elevation_m = "num!",
    type = "chr!", timezone = "chr!", county = "chr", country = "chr", aliases = "chr[]",
    network = "chr", source_id = "chr", elevation_msl_m = "num", sensor_height_agl_m = "num",
    sensor_capabilities = "chr[]", status = "chr", last_report_at = "dttm",
    last_report_summary = "json", install_date = "date", decommission_date = "date",
    update_frequency_minutes = "int", url = "chr", data_url = "chr", description_short = "chr",
    description_long = "chr", meta_title = "chr", meta_description = "chr", tags = "chr[]",
    is_featured = "lgl", indexable = "lgl!", photos = "PublicCatalogPhoto[]!",
    webcams = "PublicCatalogWebcam[]!", primary_location = "PublicCatalogPrimaryLocation",
    template = "CatalogTemplateSummary", content = "CatalogResolvedEntry[]"
  ),
  PublicCatalogPrimaryLocation = c(
    slug = "chr!", name = "chr!", lat = "num!", lon = "num!", elevation_m = "num!", type = "chr!"
  ),
  PublicCatalogElevation = c(
    label = "chr!", display_name = "chr", height_m = "num!", lat_override = "num",
    lon_override = "num", is_default = "lgl!"
  ),
  PublicCatalogPhoto = c(
    url = "chr!", caption = "chr", credit = "chr", alt_text = "chr", license = "chr",
    license_url = "chr"
  ),
  PublicCatalogWebcam = c(
    name = "chr!", url = "chr!", embed_type = "chr", provider = "chr",
    refresh_interval_seconds = "int"
  ),
  PublicCatalogNearbyStation = c(
    slug = "chr!", name = "chr!", network = "chr!", status = "chr!", distance_km = "num",
    elevation_diff_m = "num", is_primary = "lgl!"
  ),
  CmsTemplateSection = c(
    kind = "chr!", key = "chr!", config = "json"
  ),
  CatalogTemplateSummary = c(
    id = "chr!", location_type = "chr!", variant = "chr!", spec = "CmsTemplateSection[]!"
  ),
  CatalogResolvedEntry = c(
    id = "chr!", content_type_key = "chr!", title = "chr!", body = "json!", slot = "chr!",
    display_order = "int!", locale = "chr!", updated_at = "dttm!"
  ),
  # ModelMeans is an array of (id + ModelStats): this is one element.
  ModelMeansEntry = c(
    id = "chr!", temperature = "Quantiles", dewpoint = "Quantiles", precipitation = "Quantiles",
    wind_speed = "Quantiles", wind_direction = "CircularStats", snow_level = "Quantiles",
    snow_level_wet_bulb = "Quantiles", slr = "Quantiles", snowfall = "Quantiles",
    interpolated = "lgl"
  ),
  # One shape for the three FreezingLevel variants, told apart by `kind`.
  FreezingLevel = c(kind = "chr!", height = "num", above_freezing_layer_aloft = "lgl", top = "num")
)

# The package name of a field -> its wire name, for the fields BEHAVIOR.md
# 3.0 renames. Every other field is read under its own name.
wire_names <- list(
  ElevationSummary = c(height = "elevation"),
  CurrentResponse = c(now = "current"),
  PassHour = c(snow_level_margin = "snow_level_above_pass"),
  PassStatusSegment = c(state = "status", text = "status_text"),
  AlertsResponse = c(count = "alert_count", items = "alerts"),
  SnowTrendResponseElevation = c(height = "elevation"),
  SnowTrendDay = c(amount = "snow"),
  SeasonTotal = c(amount = "total"),
  RunsResponse = c(items = "runs"),
  NearbyPointResponse = c(items = "locations"),
  LocationsResponse = c(items = "locations"),
  NearbyLocationsResponse = c(origin = "location", items = "locations"),
  ProbabilityResult = c(value = "probability"),
  WindowTotal = c(start_hours = "window_start_hours", end_hours = "window_end_hours"),
  ProbabilityThresholds = c(
    daily_precipitation = "daily_precipitation_probability",
    daily_precipitation_occurrence = "daily_precipitation_occurrence_probability",
    daily_snow = "daily_snow_probability"
  ),
  ForecastResponse = c(series = "forecast", elevations = "elevation_forecasts"),
  AvalancheForecast = c(url = "forecast_url"),
  SensorObservation = c(observed_at = "observation_time"),
  CurrentStation = c(id = "station_id"),
  CurrentConditions = c(code = "condition", text = "condition_text", icon = "condition_icon"),
  ModelMembers = c(items = "members"),
  MemberForecast = c(id = "member_id"),
  MemberPlume = c(pool = "members"),
  ElevationForecast = c(height = "elevation"),
  PublicCatalogStation = c(
    source_id = "source_station_id", status = "station_status", url = "station_url"
  ),
  PublicCatalogStationDetail = c(
    source_id = "source_station_id", status = "station_status", url = "station_url"
  ),
  PublicCatalogElevation = c(height_m = "elevation_m"),
  PublicCatalogNearbyStation = c(status = "station_status"),
  CatalogTemplateSummary = c(variant = "template_variant"),
  CatalogResolvedEntry = c(locale = "resolved_locale")
)

# Nested objects flattened into the parent's columns without a prefix: the
# hourly series reads `temperature_p10`, not `ensemble_temperature_p10`.
inline_fields <- c("TimeSeriesPoint.ensemble")

# Nested objects flattened under another prefix, where the plain one would
# collide: a day's `snow_level_mean` (a number) and `snow_level` (a
# distribution, whose mean would also be `snow_level_mean`).
column_prefixes <- c("DailyForecast.snow_level" = "snow_level_dist_")
