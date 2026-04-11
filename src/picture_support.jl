function store_picture_field!(ref::Base.RefValue{T}, index::Integer, value) where {T}
    field_ptr = Ptr{fieldtype(T, index)}(
        Base.unsafe_convert(Ptr{UInt8}, Base.unsafe_convert(Ptr{T}, ref)) +
        fieldoffset(T, index)
    )
    unsafe_store!(field_ptr, convert(fieldtype(T, index), value))
    return nothing
end

function set_webp_picture_canvas!(
    picture::Base.RefValue{Wrapper.WebPPicture}, width::Integer, height::Integer
)
    store_picture_field!(picture, 1, 1)
    store_picture_field!(picture, 3, width)
    store_picture_field!(picture, 4, height)
    return nothing
end
