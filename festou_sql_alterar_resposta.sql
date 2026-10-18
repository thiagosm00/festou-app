-- Executar no SQL Editor do mesmo projeto Supabase antes de publicar o HTML.
-- Requer public.guests.edit_token uuid DEFAULT gen_random_uuid(), já confirmado.
-- Não concede UPDATE direto à tabela guests para visitantes.
CREATE OR REPLACE FUNCTION public.festou_update_rsvp(
  p_guest_id uuid,
  p_token uuid,
  p_status text,
  p_plus_ones integer,
  p_message text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_max integer;
BEGIN
  IF p_guest_id IS NULL OR p_token IS NULL OR p_status NOT IN ('confirmed','declined') THEN
    RETURN false;
  END IF;

  SELECT CASE WHEN e.allow_plus_ones THEN LEAST(GREATEST(COALESCE(e.max_plus_ones, 0), 0), 20) ELSE 0 END
    INTO v_max
  FROM public.guests g
  JOIN public.events e ON e.id = g.event_id
  WHERE g.id = p_guest_id
    AND g.edit_token = p_token
    AND e.is_published = true
    AND (e.rsvp_deadline IS NULL OR e.rsvp_deadline >= CURRENT_DATE);

  IF NOT FOUND OR v_max IS NULL OR p_plus_ones IS NULL OR p_plus_ones < 0 OR
     p_plus_ones > v_max OR (p_status = 'declined' AND p_plus_ones <> 0) THEN
    RETURN false;
  END IF;

  UPDATE public.guests
  SET status = p_status, plus_ones = p_plus_ones, message = p_message
  WHERE id = p_guest_id AND edit_token = p_token;

  RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.festou_update_rsvp(uuid,uuid,text,integer,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.festou_update_rsvp(uuid,uuid,text,integer,text) TO anon, authenticated;
