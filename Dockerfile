FROM perl:latest
RUN cpanm --notest App::Phoebe
RUN openssl req -new -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -subj "/CN=Phoebe" -addext "subjectAltName=DNS:localhost,DNS:phoebe.local" -days 1825 -nodes -out cert.pem -keyout key.pem
CMD phoebe
